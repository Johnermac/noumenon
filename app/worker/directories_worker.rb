require "httparty"
require "redis"

class DirectoriesWorker
  include Sidekiq::Worker

  def perform(site, directories, total_directories)
    begin
      directories.each do |dir|
        url = "#{site}/#{dir}"        
        response = HTTParty.get(url)

        if response && (response.success? || response.code.to_s.start_with?("3"))
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
      REDIS.set("directories_scan_complete_#{site}", "true") if processed_directories >= total_directories  
            
    rescue StandardError => e
      puts "Error during directories scan: #{e.message}"    
    end

    # ---------------------------- CLEANUP ----------------------------------------

    REDIS.expire("found_directories_#{site}", 10)
    REDIS.expire("not_found_directories_#{site}", 10)
    REDIS.expire("processed_directories_#{site}", 10)
    REDIS.expire("directories_scan_complete_#{site}", 10)

    found_directories = REDIS.smembers("found_directories_#{site}")
    not_found_directories = REDIS.smembers("not_found_directories_#{site}")

    puts "\n  Scan Results for #{site}:"
    puts "    \t✅ Found Directories: #{found_directories.join(', ')}" if found_directories.any?
    puts "    \t❌ Not Found Directories: #{not_found_directories.join(', ')}\n" if not_found_directories.any?
  end
end
