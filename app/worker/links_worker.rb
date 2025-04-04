require "httparty"
require "nokogiri"

class LinksWorker
  include Sidekiq::Worker

  def perform(url, site, total_urls)
    begin   
      valid_links = []
      response = HTTParty.get(url, headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" })


      if response.success?
        html_doc = Nokogiri::HTML(response.body)

        links = html_doc.css('a').map { |link| link['href'] }.uniq.compact

        valid_links = links.select { |link| link.start_with?('http://', 'https://') }

        REDIS.sadd("links_#{site}", valid_links) unless valid_links.empty?
        puts "---> Links extracted from #{url}: #{valid_links.size}"

        
      else
        puts "Failed to fetch URL: #{url} - Response Code: #{response.code}"
      end            
    rescue StandardError => e
      puts "Error during link scan: #{e.message}"    
    ensure
      # Track the total number of links processed
      REDIS.incrby("processed_links_#{site}", 1)

      # Check the number of completed links
      processed_links = REDIS.get("processed_links_#{site}").to_i
      puts "---> processed links: #{processed_links}/#{total_urls}"      
      REDIS.set("link_scan_complete_#{site}", "true") if processed_links >= total_urls
    end

    # ---------------------------- CLEANUP ----------------------------------------
    # Set expiration for Redis keys
    REDIS.expire("links_#{site}", 600) # Expire in 30 second (for now because i'm still testing)
    
    puts "\n  Link Results for #{url}:"
    puts "    \t✅ Found Links: #{valid_links.join(', ')}" if valid_links.any?  
  end
end
