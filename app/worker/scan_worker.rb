require "httpx"
require "redis"
require "nokogiri"


class ScanWorker  
  include Sidekiq::Worker  

  def perform(site, scan_directories, scan_subdomains, scan_links, scan_emails, scan_screenshots)

    # ---- WHATS RUNNING? -----

    puts "\n\n"
    puts " => RUN DIR!" if scan_directories
    puts " => RUN SUB!" if scan_subdomains
    puts " => RUN LINKS!" if scan_links
    puts " => RUN EMAILS!" if scan_emails
    puts " => RUN SCREENSHOT!" if scan_screenshots
    puts "\n\n"
    # -----------------  VALIDATE WORDLIST  ---------------------
 
    wordlist_path = Rails.root.join("wordlist.txt")

    unless File.exist?(wordlist_path)
      puts "\n\t❌ Wordlist file not found at #{wordlist_path}"
      return
    end

    # ---------------------  DIR  ------------------------------

    directories = File.readlines(wordlist_path).map(&:strip).reject(&:empty?)        

    if scan_directories
      directories.each_slice(50) do |batch|
        DirectoriesWorker.perform_async(site, batch, directories.size)
      end
    end   

    # ---------------------  SUB  ------------------------------

    if scan_subdomains
      found_subdomains = []

      found_subdomains = run_subdomains(site)      

      total_subdomains = found_subdomains.length
      REDIS.set("subdomain_scan_complete_#{site}", false)

      found_subdomains.each_slice(50) do |subdomain|
        SubdomainWorker.perform_async(site, subdomain, total_subdomains)
      end

      REDIS.set("scan_results_#{site}_subdomains", { found_subdomains: found_subdomains }.to_json)
      REDIS.expire("scan_results_#{site}_subdomains", 10)

      puts "\n  Scan Results for #{site}:"
      puts "    \t🟡 Found Subdomains: #{found_subdomains.join(', ')}" if found_subdomains.any?           

    end

    # ---------------------  LINKS || EMAILS || SCREENSHOTS ------------------------------

    if scan_links || scan_emails || scan_screenshots
      wait_scans(site, scan_directories, scan_subdomains, scan_links, scan_emails, scan_screenshots)      
    end    
  end

  private

  def run_subdomains(site)
    found_subdomains = []    

    stripped_site = site.gsub(/https?:\/\/(www\.)?/, "").gsub(/(www\.)?/, "")

    puts "--->  stripped_site: #{stripped_site}"

    # 1 - Getting subdomains from crt.sh    
    response = HTTPX.get("https://crt.sh/?q=#{stripped_site}")

    if response.is_a?(HTTPX::Response) && response.status.to_s.start_with?("2", "3")
      html_doc = Nokogiri::HTML(response.to_s) # Convert response body to string

      html_doc.css('td').each do |td|
        found_subdomains += td.text.scan(/[a-z0-9]+\.#{Regexp.escape(stripped_site)}/)
      end        
    else
      puts "❌ Failed to fetch subdomains (Response: #{response.inspect})"
    end

    found_subdomains.uniq
  end


  def wait_scans(site, scan_directories, scan_subdomains, scan_links, scan_emails, scan_screenshots)
    directories_done = !scan_directories # If not scanning directories, consider it done
    subdomains_done = !scan_subdomains   # If not scanning subdomains, consider it done
    start_time = Time.now                # Track start time to enforce timeout (optional)
  
    # Periodically check status every 10 seconds
    
    loop do
      # Check if directories scan is done
      if scan_directories && !directories_done
        directories_done = REDIS.get("directories_scan_complete_#{site}") == "true"
        puts "\n => Checking directories scan: #{directories_done ? 'Complete' : 'Still running...'}"
      end

      # Check if subdomains scan is done
      if scan_subdomains && !subdomains_done
        subdomains_done = REDIS.get("subdomain_scan_complete_#{site}") == "true"
        puts "\n => Checking subdomains scan: #{subdomains_done ? 'Complete' : 'Still running...'}"
      end

      # Break the loop if both scans are complete
      break if directories_done && subdomains_done          

      # Optional timeout (e.g., after 5 minutes)
      if Time.now - start_time > 300 # Timeout after 5 minutes
        puts "\n❌ Timeout waiting for scans to complete!"
        break
      end

      sleep(15) # Pause for 10 seconds before checking again
    end

    # ===> SEND TO SCAN LINKS

    if directories_done && subdomains_done && (scan_links || scan_emails || scan_screenshots)        
      
      puts "\n\t   🔗 Links Scan..." if scan_links
      puts "\n\t   📧 Emails Scan..." if scan_emails
      puts "\n\t   📷 Screenshots..." if scan_screenshots
    
      prepare_scans(site, scan_directories, scan_subdomains, scan_links, scan_emails, scan_screenshots)
    end    
  end
  

  def prepare_scans(site, scan_directories, scan_subdomains, scan_links, scan_emails, scan_screenshots)    

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

    # Add main site URL
    urls << "#{site}"

    #puts "\n => URLS: #{urls}"    

    total_urls = urls.length

    ScreenshotsWorker.perform_async(urls, site) if scan_screenshots

    urls.each do |url|
      LinksWorker.perform_async(url, site, total_urls) if scan_links  
      EmailsWorker.perform_async(url, site, total_urls) if scan_emails  
    end
  end
end