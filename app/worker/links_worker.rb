require "httparty"
require "nokogiri"

class LinksWorker
  include Sidekiq::Worker

  def perform(url, site)
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
    end

    # ---------------------------- CLEANUP ----------------------------------------
    # Set expiration for Redis keys
    REDIS.expire("links_#{site}", 300) # Expire in 30 second (for now because i'm still testing)
    
    puts "\n  Link Results for #{url}:"
    puts "    \t✅ Found Links: #{valid_links.join(', ')}" if valid_links.any?  
  end
end
