require "httparty"
require "redis"
require "nokogiri"


class ScanWorker
  include HTTParty
  include Sidekiq::Worker  

  def perform(site, scan_directories, scan_subdomains)

    puts "\n => RUN DIR? #{scan_directories}"
    puts "\n => RUN SUB? #{scan_subdomains}"

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
end