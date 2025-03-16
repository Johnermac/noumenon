require "httparty"
require "redis"
require "nokogiri"


class ScanWorker
  include HTTParty
  include Sidekiq::Worker  

  def perform(site, scan_directories, scan_subdomains, scan_links)

    puts "\n => RUN DIR? #{scan_directories}"
    puts "\n => RUN SUB? #{scan_subdomains}"
    puts "\n => RUN LINKS? #{scan_links}"

    # -----------------  VALIDATE WORDLIST  ---------------------
 
    wordlist_path = Rails.root.join("tmp", "wordlist.txt")

    unless File.exist?(wordlist_path)
      puts "\n\t❌ Wordlist file not found at #{wordlist_path}"
      return
    end

    # ---------------------  DIR  ------------------------------

    directories = File.readlines(wordlist_path).map(&:strip).reject(&:empty?)        

    if scan_directories
      directories.each_slice(100) do |batch|
        DirectoriesWorker.perform_async(site, batch, directories.size)
      end
    end   

    # ---------------------  SUB  ------------------------------

    if scan_subdomains
      found_subdomains = []

      found_subdomains = run_subdomains(site)

      #found_subdomains = found_subdomains || []

      total_subdomains = found_subdomains.length
      REDIS.set("subdomain_scan_complete_#{site}", false)

      found_subdomains.each do |subdomain|
        SubdomainWorker.perform_async(site, subdomain, total_subdomains)
      end

      REDIS.set("scan_results_#{site}_subdomains", { found_subdomains: found_subdomains }.to_json)
      REDIS.expire("scan_results_#{site}_subdomains", 10)

      puts "\n  Scan Results for #{site}:"
      puts "    \t🟡 Found Subdomains: #{found_subdomains.join(', ')}" if found_subdomains.any?
      #puts "    \t🟢 Active Subdomains: #{active_subdomains.join(', ')}\n" if active_subdomains.any?      

    end

    # ---------------------  LINKS  ------------------------------

    if scan_links
      wait_links(site, scan_directories, scan_subdomains)

      urls_to_process = run_links(site, scan_directories, scan_subdomains)

      # Enqueue LinksWorker for each URL
      urls_to_process.each do |url|
        LinksWorker.perform_async(url, site)
      end
    end
  end

  private

  def run_subdomains(site)
    found_subdomains = []    

    stripped_site = site.gsub(/https?:\/\/(www\.)?/, "").gsub(/(www\.)?/, "")

    puts "--->  stripped_site: #{stripped_site}"

    # 1 - Getting subdomains from crt.sh    
    response = HTTParty.get("https://crt.sh/?q=#{stripped_site}")
    html_doc = Nokogiri::HTML(response.body)

    
    #puts html_doc.to_html

    html_doc.css('td').each do |td|
      found_subdomains += td.text.scan(/[a-z0-9]+\.#{Regexp.escape(stripped_site)}/)
    end        

    # puts "--->  found_subdomains: #{found_subdomains.uniq}"

    found_subdomains.uniq

  end

  def wait_links(site, scan_directories, scan_subdomains)
    # Wait for directories scan to complete
    if scan_directories
      until REDIS.get("directories_scan_complete_#{site}") == "true"
        puts "Waiting for directories scan to complete..."
        sleep(5) # Check every 5 seconds
      end
    end

    # Wait for subdomains scan to complete
    if scan_subdomains
      until REDIS.get("subdomain_scan_complete_#{site}") == "true"
        puts "Waiting for subdomain scan to complete..."
        sleep(5) # Check every 5 seconds
      end
    end
  end

  def run_links(site, scan_directories, scan_subdomains)
    urls = []

    # Add directory URLs
    if scan_directories
      found_directories = REDIS.smembers("found_directories_#{site}")
      urls += found_directories.map { |dir| "#{site}/#{dir}" } if found_directories.any?
    end

    # Add subdomain URLs
    if scan_subdomains
      active_subdomains = REDIS.smembers("active_subdomains_#{site}")
      urls += active_subdomains.map { |sub| "http://#{sub}" } if active_subdomains.any?
    end

    # Add main site URL if no directories or subdomains are scanned
    urls << "#{site}" if urls.empty?

    urls
  end
end