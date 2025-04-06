require "typhoeus"
require "redis"

class SubdomainWorker
  include Sidekiq::Worker

  def perform(site, subdomains, total_subdomains)
    begin
      hydra = Typhoeus::Hydra.hydra

      # Queue requests for all subdomains
      subdomains.each do |subdomain|
        request = Typhoeus::Request.new(
          "http://#{subdomain}",
          followlocation: true,
          timeout: 5 # Short timeout to avoid long delays
        )

        # Handle response for each subdomain
        request.on_complete do |response|
          if response.success? || response.code.to_s.start_with?("3")
            REDIS.sadd("active_subdomains_#{site}", subdomain)
            puts "---> Active subdomain: #{subdomain}"          
          end
        end

        hydra.queue(request) # Add request to Hydra queue
      end

      hydra.run
           
    rescue StandardError => e
      puts "Error processing subdomains batch for #{site}: #{e.message}"   
    ensure
      # Track the total number of subdomains processed (active or inactive)
      REDIS.incrby("processed_subdomains_#{site}", subdomains.size)

      # Check the number of completed subdomains
      processed_subdomains = REDIS.get("processed_subdomains_#{site}").to_i
      puts "---> Processed subdomains: #{processed_subdomains}/#{total_subdomains}" 
           
      if processed_subdomains >= total_subdomains       
        REDIS.set("subdomain_scan_complete_#{site}", "true") 
        # -------------------- CLEANUP --------------------

        REDIS.expire("processed_subdomains_#{site}", 600)
        REDIS.expire("active_subdomains_#{site}", 600)
      end
    end    
  end
end
