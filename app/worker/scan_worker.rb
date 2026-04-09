require "httpx"
require "redis"
require "nokogiri"
require "json"

class ScanWorker  
  include Sidekiq::Worker  
  DIR_BATCH_SIZE = 30
  PHASE_ONE_MIN_HIT_RATE = 0.02
  PHASE_TWO_MIN_HIT_RATE = 0.01
  TELEMETRY_TTL = 7200

  def perform(site, scan_directories, scan_subdomains, scan_links, scan_emails, scan_screenshots)
    reset_scan_state(site, scan_directories, scan_subdomains, scan_links, scan_emails, scan_screenshots)

    # ---- WHATS RUNNING? -----

    puts "\n\n"
    puts " => RUN DIR!" if scan_directories
    puts " => RUN SUB!" if scan_subdomains
    puts " => RUN LINKS!" if scan_links
    puts " => RUN EMAILS!" if scan_emails
    puts " => RUN SCREENSHOT!" if scan_screenshots
    puts "\n\n"
    # -----------------  VALIDATE WORDLIST  ---------------------
 
    # ---------------------  SUB  ------------------------------

    if scan_subdomains
      found_subdomains = []

      found_subdomains = run_subdomains(site)      

      total_subdomains = found_subdomains.length
      REDIS.set("subdomain_scan_complete_#{site}", false)
      REDIS.expire("subdomain_scan_complete_#{site}", TELEMETRY_TTL)

      if total_subdomains.zero?
        REDIS.set("subdomain_scan_complete_#{site}", "true")
      else
        found_subdomains.each_slice(50) do |subdomain|
          SubdomainWorker.perform_async(site, subdomain, total_subdomains)
        end
      end

      REDIS.set("scan_results_#{site}_subdomains", { found_subdomains: found_subdomains }.to_json)
      REDIS.expire("scan_results_#{site}_subdomains", TELEMETRY_TTL)

      puts "\n  Scan Results for #{site}:"
      puts "    \t🟡 Found Subdomains: #{found_subdomains.join(', ')}" if found_subdomains.any?           

    end

    # ---------------------  DIR  ------------------------------

    if scan_directories
      run_smart_directories_scan(site)
    end

    # ---------------------  LINKS || EMAILS || SCREENSHOTS ------------------------------

    if scan_links || scan_emails || scan_screenshots
      wait_scans(site, scan_directories, scan_subdomains, scan_links, scan_emails, scan_screenshots)      
    end    
  end

  private

  def run_smart_directories_scan(site)
    REDIS.set("directories_scan_complete_#{site}", "false")
    REDIS.set("directories_scan_phase_#{site}", "preflight")
    REDIS.del("directories_scan_error_#{site}")
    REDIS.expire("directories_scan_complete_#{site}", TELEMETRY_TTL)
    REDIS.expire("directories_scan_phase_#{site}", TELEMETRY_TTL)

    base_wordlist = load_base_wordlist
    if base_wordlist.empty?
      REDIS.set("directories_scan_complete_#{site}", "true")
      REDIS.set("directories_scan_phase_#{site}", "completed")
      REDIS.set("directories_scan_error_#{site}", "wordlist.txt is missing or empty")
      REDIS.expire("directories_scan_complete_#{site}", TELEMETRY_TTL)
      REDIS.expire("directories_scan_phase_#{site}", TELEMETRY_TTL)
      REDIS.expire("directories_scan_error_#{site}", TELEMETRY_TTL)
      return
    end

    begin
      preflight = DirectoryPreflightService.new(site).call
      phased_wordlist = SmartWordlistService.new(base_wordlist: base_wordlist, preflight: preflight).build

      REDIS.set("directories_waf_detected_#{site}", preflight[:waf_detected] ? "true" : "false")
      REDIS.set("directories_phase_hit_rates_#{site}", {}.to_json)
      REDIS.set("directories_scan_phase_#{site}", "phase_1")
      REDIS.expire("directories_waf_detected_#{site}", TELEMETRY_TTL)
      REDIS.expire("directories_phase_hit_rates_#{site}", TELEMETRY_TTL)
      REDIS.expire("directories_scan_phase_#{site}", TELEMETRY_TTL)

      phase_1_processed, phase_1_found = enqueue_and_wait_phase(
        site: site,
        phase_key: "phase_1",
        words: phased_wordlist[:phase_1],
        mark_complete: false,
        fingerprint: preflight[:fingerprint]
      )
      phase_1_hit_rate = hit_rate(phase_1_found, phase_1_processed)

      if phase_1_hit_rate >= PHASE_ONE_MIN_HIT_RATE
        phase_2_processed, phase_2_found = enqueue_and_wait_phase(
          site: site,
          phase_key: "phase_2",
          words: phased_wordlist[:phase_2],
          mark_complete: false,
          fingerprint: preflight[:fingerprint]
        )
        phase_2_hit_rate = hit_rate(phase_2_found, phase_2_processed)

        if phase_2_hit_rate >= PHASE_TWO_MIN_HIT_RATE
          enqueue_and_wait_phase(
            site: site,
            phase_key: "phase_3",
            words: phased_wordlist[:phase_3],
            mark_complete: true,
            fingerprint: preflight[:fingerprint]
          )
        else
          REDIS.set("directories_scan_complete_#{site}", "true")
          REDIS.set("directories_scan_phase_#{site}", "completed")
        end
      else
        REDIS.set("directories_scan_complete_#{site}", "true")
        REDIS.set("directories_scan_phase_#{site}", "completed")
      end

      REDIS.expire("directories_scan_complete_#{site}", TELEMETRY_TTL)
      REDIS.expire("directories_scan_phase_#{site}", TELEMETRY_TTL)
    rescue StandardError => e
      REDIS.set("directories_scan_complete_#{site}", "true")
      REDIS.set("directories_scan_phase_#{site}", "error")
      REDIS.set("directories_scan_error_#{site}", concise_error(e))
      REDIS.expire("directories_scan_complete_#{site}", TELEMETRY_TTL)
      REDIS.expire("directories_scan_phase_#{site}", TELEMETRY_TTL)
      REDIS.expire("directories_scan_error_#{site}", TELEMETRY_TTL)
      puts "❌ Directory scan failed for #{site}: #{e.class} - #{e.message}"
      raise
    end
  end

  def enqueue_and_wait_phase(site:, phase_key:, words:, mark_complete:, fingerprint:)
    sanitized_words = words.map(&:to_s).map(&:strip).reject(&:empty?).uniq
    if sanitized_words.empty?
      if mark_complete
        REDIS.set("directories_scan_complete_#{site}", "true")
        REDIS.set("directories_scan_phase_#{site}", "completed")
        REDIS.expire("directories_scan_complete_#{site}", TELEMETRY_TTL)
        REDIS.expire("directories_scan_phase_#{site}", TELEMETRY_TTL)
      end
      return [0, 0]
    end

    total = sanitized_words.size
    processed_key = "processed_directories_#{site}_#{phase_key}"

    REDIS.del(processed_key)
    REDIS.set("directories_scan_phase_#{site}", phase_key)
    REDIS.set("directories_scan_phase_total_#{site}", total)
    REDIS.expire("directories_scan_phase_#{site}", 1500)
    REDIS.expire("directories_scan_phase_total_#{site}", 1500)

    found_before = REDIS.scard("found_directories_#{site}")

    sanitized_words.each_slice(DIR_BATCH_SIZE) do |batch|
      DirectoriesWorker.perform_async(site, batch, total, phase_key, mark_complete, fingerprint)
    end

    wait_for_directory_phase(site, total, phase_key)
    found_after = REDIS.scard("found_directories_#{site}")
    phase_found = [found_after - found_before, 0].max
    persist_phase_hit_rate(site, phase_key, hit_rate(phase_found, total))
    REDIS.set("directories_scan_phase_#{site}", "completed") if mark_complete
    REDIS.expire("directories_scan_phase_#{site}", TELEMETRY_TTL) if mark_complete
    [total, phase_found]
  end

  def wait_for_directory_phase(site, total, phase_key)
    start_time = Time.now
    processed_key = "processed_directories_#{site}_#{phase_key}"

    loop do
      processed = REDIS.get(processed_key).to_i
      break if processed >= total

      if Time.now - start_time > 300
        puts "\n❌ Timeout waiting for directory #{phase_key} to complete!"
        break
      end

      sleep(2)
    end
  end

  def hit_rate(found_count, processed_count)
    return 0.0 if processed_count <= 0
    found_count.to_f / processed_count.to_f
  end

  def persist_phase_hit_rate(site, phase_key, rate)
    raw = REDIS.get("directories_phase_hit_rates_#{site}")
    rates = raw.present? ? JSON.parse(raw) : {}
    rates[phase_key] = (rate * 100.0).round(2)
    REDIS.set("directories_phase_hit_rates_#{site}", rates.to_json)
    REDIS.expire("directories_phase_hit_rates_#{site}", TELEMETRY_TTL)
  rescue JSON::ParserError
    REDIS.set("directories_phase_hit_rates_#{site}", { phase_key => (rate * 100.0).round(2) }.to_json)
    REDIS.expire("directories_phase_hit_rates_#{site}", TELEMETRY_TTL)
  end

  def concise_error(error)
    "#{error.class}: #{error.message.to_s.split("\n").first}".slice(0, 220)
  end

  def load_base_wordlist
    wordlist_path = Rails.root.join("wordlist.txt")

    unless File.exist?(wordlist_path)
      puts "\n\t❌ Wordlist file not found at #{wordlist_path}"
      return []
    end

    File.readlines(wordlist_path).map(&:strip).reject(&:empty?)
  end

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
      if Time.now - start_time > 1800 # Timeout after 30 minutes
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

  def reset_scan_state(site, scan_directories, scan_subdomains, scan_links, scan_emails, scan_screenshots)
    scan_options = {
      scan_directories: !!scan_directories,
      scan_subdomains: !!scan_subdomains,
      scan_links: !!scan_links,
      scan_emails: !!scan_emails,
      scan_screenshots: !!scan_screenshots
    }
    REDIS.set("scan_options_#{site}", scan_options.to_json)
    REDIS.expire("scan_options_#{site}", TELEMETRY_TTL)

    if scan_directories
      REDIS.del("found_directories_#{site}", "not_found_directories_#{site}", "directories_scan_error_#{site}",
                "directories_phase_hit_rates_#{site}", "directories_scan_phase_#{site}",
                "directories_scan_phase_total_#{site}", "directories_scan_started_at_#{site}")
      REDIS.set("directories_scan_complete_#{site}", "false")
      REDIS.expire("directories_scan_complete_#{site}", TELEMETRY_TTL)
    else
      REDIS.del("found_directories_#{site}", "not_found_directories_#{site}", "directories_scan_error_#{site}",
                "directories_phase_hit_rates_#{site}", "directories_scan_phase_#{site}",
                "directories_scan_phase_total_#{site}", "directories_scan_started_at_#{site}",
                "directories_waf_detected_#{site}")
      REDIS.set("directories_scan_complete_#{site}", "true")
      REDIS.expire("directories_scan_complete_#{site}", TELEMETRY_TTL)
    end

    if scan_subdomains
      REDIS.del("active_subdomains_#{site}", "processed_subdomains_#{site}", "scan_results_#{site}_subdomains")
      REDIS.set("subdomain_scan_complete_#{site}", "false")
      REDIS.expire("subdomain_scan_complete_#{site}", TELEMETRY_TTL)
    else
      REDIS.del("active_subdomains_#{site}", "processed_subdomains_#{site}", "scan_results_#{site}_subdomains")
      REDIS.set("subdomain_scan_complete_#{site}", "true")
      REDIS.expire("subdomain_scan_complete_#{site}", TELEMETRY_TTL)
    end

    if scan_links
      REDIS.del("links_#{site}", "processed_links_#{site}")
      REDIS.set("link_scan_complete_#{site}", "false")
      REDIS.expire("link_scan_complete_#{site}", TELEMETRY_TTL)
    else
      REDIS.del("links_#{site}", "processed_links_#{site}")
      REDIS.set("link_scan_complete_#{site}", "true")
      REDIS.expire("link_scan_complete_#{site}", TELEMETRY_TTL)
    end

    if scan_emails
      REDIS.del("emails_#{site}", "processed_emails_#{site}")
      REDIS.set("email_scan_complete_#{site}", "false")
      REDIS.expire("email_scan_complete_#{site}", TELEMETRY_TTL)
    else
      REDIS.del("emails_#{site}", "processed_emails_#{site}")
      REDIS.set("email_scan_complete_#{site}", "true")
      REDIS.expire("email_scan_complete_#{site}", TELEMETRY_TTL)
    end

    if scan_screenshots
      REDIS.del("processed_screenshots_#{site}", "screenshot_scan_error_#{site}",
                "screenshot_worker_lock_#{site}", "screenshot_cleanup_started_#{site}",
                "expected_screenshots_#{site}", "screenshot_zip_password_#{site}")
      REDIS.set("screenshot_scan_complete_#{site}", "false")
      REDIS.expire("screenshot_scan_complete_#{site}", TELEMETRY_TTL)
    else
      REDIS.del("processed_screenshots_#{site}", "screenshot_scan_error_#{site}",
                "screenshot_worker_lock_#{site}", "screenshot_cleanup_started_#{site}",
                "expected_screenshots_#{site}", "screenshot_zip_password_#{site}")
      REDIS.set("screenshot_scan_complete_#{site}", "true")
      REDIS.expire("screenshot_scan_complete_#{site}", TELEMETRY_TTL)
    end
  end
end
