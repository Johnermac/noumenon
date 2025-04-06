require "httparty"
require "nokogiri"

class EmailsWorker
  include Sidekiq::Worker

  def perform(url, site, total_urls)
    begin   
      valid_emails = []
      response = HTTParty.get(url, headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" })


      if response.success?
        html_doc = Nokogiri::HTML(response.body)

        text = html_doc.text
        valid_emails = text.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i).uniq

        REDIS.sadd("emails_#{site}", valid_emails) unless valid_emails.empty?
        puts "---> Emails extracted from #{url}: #{valid_emails.size}"

        
      else
        puts "Failed to fetch URL: #{url} - Response Code: #{response.code}"
      end            
    rescue StandardError => e
      puts "Error during email scan: #{e.message}"    
    ensure
      # Track the total number of emails processed
      REDIS.incrby("processed_emails_#{site}", 1)

      # Check the number of completed emails
      processed_emails = REDIS.get("processed_emails_#{site}").to_i
      puts "---> processed emails: #{processed_emails}/#{total_urls}" 
           
      if processed_emails >= total_urls
        REDIS.set("email_scan_complete_#{site}", "true") 
        # ---------------------------- CLEANUP ----------------------------------------
        # Set expiration for Redis keys
        REDIS.expire("emails_#{site}", 600) # Expire in 30 second (for now because i'm still testing)
        REDIS.expire("processed_emails_#{site}", 300)
        REDIS.expire("emails_scan_complete_#{site}", 300)
        
        puts "\n  Email Results for #{url}:"
        puts "    \t✅ Found Emails: #{valid_emails.join(', ')}" if valid_emails.any? 
      end
    end     
  end
end
