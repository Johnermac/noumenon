require "httpx"
require "nokogiri"

class EmailsWorker
  include Sidekiq::Worker

  def perform(url, site, total_urls)
    begin   
      valid_emails = []
      response = HTTPX.get(url, headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" })
    
      if response.is_a?(HTTPX::Response) && response.status.to_s.start_with?("2", "3")
        html_doc = Nokogiri::HTML(response.to_s) # Convert response to string for Nokogiri    
        text = html_doc.text
        valid_emails = text.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i).uniq
    
        REDIS.sadd("emails_#{site}", valid_emails) unless valid_emails.empty?
    
        # Track the total number of emails processed
        REDIS.incrby("processed_emails_#{site}", 1)
    
        # Check the number of completed emails
        processed_emails = REDIS.get("processed_emails_#{site}").to_i
        puts "---> processed emails: #{processed_emails}/#{total_urls}"     
      else
        puts "❌ Failed to fetch URL: #{url}"
      end            
    
    rescue HTTPX::ConnectionError => e
      puts "❌ Connection error for #{url}: #{e.message} - Retrying..."
      sleep(1)
      retry      
    rescue StandardError => e
      puts "Error during email scan: #{e.message}"      
    ensure            
      processed_emails = REDIS.get("processed_emails_#{site}").to_i
      cleanup_emails(site, valid_emails) if processed_emails >= total_urls      
    end        
  end

  private

  def cleanup_emails(site, valid_emails)
    REDIS.set("email_scan_complete_#{site}", "true") 

    # ---------------------------- CLEANUP ----------------------------------------

    REDIS.expire("emails_#{site}", 600)
    REDIS.expire("processed_emails_#{site}", 300)
    REDIS.expire("emails_scan_complete_#{site}", 300)
    
    puts "\n  Email Results for #{site}:"
    puts "    \t✅ Found Emails: #{valid_emails.join(', ')}" if valid_emails.any? 
  end
end
