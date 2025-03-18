require "httparty"
require "redis"

class SubdomainWorker
  include Sidekiq::Worker

  def perform(site, subdomain, total_subdomains)
    begin
      puts "---> Performing for subdomain: #{subdomain}, total_subdomains: #{total_subdomains}"
      response = HTTParty.get("http://#{subdomain}")
      if response.success? || response.code.to_s.start_with?("3")
        REDIS.sadd("active_subdomains_#{site}", subdomain)
        puts "\n---> active-sub: #{subdomain}"
      end     
    rescue StandardError => e
      puts "Error processing subdomain #{subdomain}: #{e.message}"      
    ensure
       # Track the total number of subdomains processed (active or inactive)
       REDIS.incrby("processed_subdomains_#{site}", 1)

       # Check the number of completed subdomains
       processed_subdomains = REDIS.get("processed_subdomains_#{site}").to_i
       puts "\n---> processed_subdomains: #{processed_subdomains}, total_subdomains: #{total_subdomains}"
       REDIS.set("subdomain_scan_complete_#{site}", "true") if processed_subdomains >= total_subdomains       
    end

    # -------------------- CLEANUP --------------------

    REDIS.expire("processed_subdomains_#{site}", 600)
    REDIS.expire("active_subdomains_#{site}", 600)
  end
end
