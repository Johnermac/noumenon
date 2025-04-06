#require "httparty"
require "redis"
require 'httpx'



class DirectoriesWorker
  include Sidekiq::Worker

  def perform(site, directories, total_directories)
    begin
      directories.each do |dir|
        url = "#{site}/#{dir}"        

        response = HTTPX.get(url, headers: {
          "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0"
        })

        #puts "\n\n\n => #{response.status}"

        if response && (response.status.to_s.start_with?("2") || response.status.to_s.start_with?("3"))
          REDIS.sadd("found_directories_#{site}", dir) unless dir.empty?
        else
          puts "Failed or error processing #{url}" unless dir.empty?
          REDIS.sadd("not_found_directories_#{site}", dir) unless dir.empty?
        end

        REDIS.incrby("processed_directories_#{site}", 1)
        
      end      

      # Check the number of completed subdomains
      processed_directories = REDIS.get("processed_directories_#{site}").to_i   
      puts "---> Processed directories: #{processed_directories}, Total: #{total_directories}" 
      cleanup_directories(site) if processed_directories >= total_directories      
    
    rescue StandardError => e
      puts "Error during directories scan: #{e.message}"    
    end    
  end

  private

  def cleanup_directories(site)
    REDIS.set("directories_scan_complete_#{site}", "true") 

    # ---------------------------- CLEANUP ----------------------------------------

    REDIS.expire("found_directories_#{site}", 600)
    REDIS.expire("not_found_directories_#{site}", 600)
    REDIS.expire("processed_directories_#{site}", 600)
    REDIS.expire("directories_scan_complete_#{site}", 600)

    found_directories = REDIS.smembers("found_directories_#{site}")
    not_found_directories = REDIS.smembers("not_found_directories_#{site}")

    puts "\n  Scan Results for #{site}:"
    puts "    \t✅ Found Directories: #{found_directories.join(', ')}" if found_directories.any?
    puts "    \t❌ Not Found Directories: #{not_found_directories.join(', ')}\n" if not_found_directories.any?
  end
end
