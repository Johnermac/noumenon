require "httparty"
require "redis"

class SubdomainWorker
  include Sidekiq::Worker  

  def perform(site, subdomain, total_subdomains)
    response = HTTParty.get("http://#{subdomain}")
    if response.success? || response.code.to_s.start_with?("3")
      REDIS.sadd("active_subdomains_#{site}", subdomain)
      puts "--->active-sub: #{subdomain}"
    end

    # Check the number of completed subdomains
    completed_subdomains = REDIS.scard("active_subdomains_#{site}")
    if completed_subdomains >= total_subdomains
      REDIS.set("subdomain_scan_complete_#{site}", true)
    end
  rescue StandardError => e
    puts e.message
  end
end
