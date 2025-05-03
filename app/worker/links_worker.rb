require "httpx"
require "nokogiri"

class LinksWorker
  include Sidekiq::Worker

  def perform(url, site, total_urls)
    begin   
      valid_links = []
      response = HTTPX.get(url, headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" })
    
      if response.is_a?(HTTPX::Response) && response.status.to_s.start_with?("2", "3")
        html_doc = Nokogiri::HTML(response.to_s) # Convert response to string for Nokogiri    
        links = html_doc.css('a').map { |link| link['href'] }.uniq.compact    
        valid_links = links.select { |link| link.start_with?('http://', 'https://') }
    
        REDIS.sadd("links_#{site}", valid_links) unless valid_links.empty?    
               
        processed_links = REDIS.get("processed_links_#{site}").to_i
        puts "---> processed links: #{processed_links}/#{total_urls}"     
      else
        puts "❌ Failed to fetch URL: #{url}"
      end            
    
    rescue HTTPX::ConnectionError => e
      puts "❌ Connection error for #{url}: #{e.message} - Retrying..."
      sleep(5)
      retry    
    rescue StandardError => e
      puts "Error during link scan: #{e.message}"     
    ensure     
      REDIS.incrby("processed_links_#{site}", 1)       
      processed_links = REDIS.get("processed_links_#{site}").to_i   
      cleanup_links(site, valid_links) if processed_links >= total_urls      
    end   
  end 
    

  private

  def cleanup_links(site, valid_links)
    REDIS.set("link_scan_complete_#{site}", "true") 

    # ---------------------------- CLEANUP ----------------------------------------

    REDIS.expire("links_#{site}", 600) 
    REDIS.expire("processed_links_#{site}", 300)
    REDIS.expire("links_scan_complete_#{site}", 300)
    
    puts "\n  Link Results for #{site}:"
    puts "    \t✅ Found Links: #{valid_links.join(', ')}" if valid_links.any?
  end
end
