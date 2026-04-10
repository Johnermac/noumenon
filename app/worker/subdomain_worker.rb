require "httpx"
require "redis"

class SubdomainWorker
  include Sidekiq::Worker
  RESULT_TTL = 7200
  REQUEST_TIMEOUT = { connect_timeout: 5, operation_timeout: 5 }.freeze

  def perform(site, subdomains, total_subdomains)
    begin
      subdomains.each do |subdomain|
        response = HTTPX.with(timeout: REQUEST_TIMEOUT, follow_redirects: true).get("http://#{subdomain}")

        if response.is_a?(HTTPX::Response) && response.status.to_s.start_with?("2", "3")
          REDIS.sadd("active_subdomains_#{site}", subdomain)
          puts "---> Active subdomain: #{subdomain}"
        end
      end
    
    rescue HTTPX::Error => e
      puts "HTTP error processing subdomains batch for #{site}: #{e.message}"
    rescue StandardError => e
      puts "Error processing subdomains batch for #{site}: #{e.message}"
    ensure
      # Track the total number of subdomains processed (active or inactive)
      REDIS.incrby("processed_subdomains_#{site}", subdomains.size)

      # Check the number of completed subdomains
      processed_subdomains = REDIS.get("processed_subdomains_#{site}").to_i
      puts "---> Processed subdomains: #{processed_subdomains}/#{total_subdomains}"            
      cleanup_subdomains(site) if processed_subdomains >= total_subdomains     
      
    end    
  end

  private

  def cleanup_subdomains(site)
    REDIS.set("subdomain_scan_complete_#{site}", "true") 

    # -------------------- CLEANUP --------------------

    REDIS.expire("processed_subdomains_#{site}", RESULT_TTL)
    REDIS.expire("active_subdomains_#{site}", RESULT_TTL)
    REDIS.expire("subdomain_scan_complete_#{site}", RESULT_TTL)
  end
end
