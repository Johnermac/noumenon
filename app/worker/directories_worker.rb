require "redis"
require 'httpx'

class DirectoriesWorker
  include Sidekiq::Worker

  def perform(site, directories, total_directories)
    begin
      REDIS.set("directories_scan_started_at_#{site}", Time.now.to_i) unless REDIS.exists?("directories_scan_started_at_#{site}")

      # Hash a invalid dir and compare 
      fingerprint ||= generate_fingerprint(site)

      directories.each do |dir|
        url = "#{site}/#{dir}"        

        response = HTTPX.get(url, headers: {
          "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0"
        })        

        if response.is_a?(HTTPX::Response) && response.status.to_s.start_with?("2")
          if fingerprint && false_positive?(response, fingerprint)
            # puts "⚠️ Skipped false-positive: #{dir}"
            REDIS.sadd("not_found_directories_#{site}", dir)
            
          else
            REDIS.sadd("found_directories_#{site}", dir) unless dir.empty?
            puts "\tFOUND: #{dir}"
          end          
        else
          # puts "Failed or error processing #{url} (Response: #{response.inspect})" unless dir.empty?
          REDIS.sadd("not_found_directories_#{site}", dir) unless dir.empty?
        end

        REDIS.incrby("processed_directories_#{site}", 1)
        
      end      
      
      processed_directories = REDIS.get("processed_directories_#{site}").to_i 
      check_progress(site, total_directories, processed_directories)      
      cleanup_directories(site) if processed_directories >= total_directories      
    
    rescue HTTPX::ConnectionError => e
      puts "❌ Connection error for #{url}: #{e.message} - Retrying..."
      sleep(1)
      retry
    
    rescue StandardError => e
      puts "Error during directories scan: #{e.message}"
    end
  end

  private

  def cleanup_directories(site)
    REDIS.set("directories_scan_complete_#{site}", "true") 

    # ---------------------------- CLEANUP ----------------------------------------

    REDIS.expire("found_directories_#{site}", 10)
    REDIS.expire("not_found_directories_#{site}", 10)
    REDIS.expire("processed_directories_#{site}", 10)
    REDIS.expire("directories_scan_complete_#{site}", 10)
    REDIS.expire("directories_scan_started_at_#{site}", 10)

    

    found_directories = REDIS.smembers("found_directories_#{site}")
    not_found_directories = REDIS.smembers("not_found_directories_#{site}")

    puts "\n  Scan Results for #{site}:"
    puts "    \t✅ Found Directories: #{found_directories.join(', ')}" if found_directories.any?
    puts "    \t❌ Not Found Directories: #{not_found_directories.join(', ')}\n" if not_found_directories.any?
  end

  def check_progress(site, total_directories, processed_directories)
    # Check the number of completed subdomains      
    start_time = REDIS.get("directories_scan_started_at_#{site}").to_i

    return unless Time.now.min.even? && Time.now.sec == 0
    
    if start_time > 0 && processed_directories > 0
      percent = ((processed_directories / total_directories.to_f) * 100).round(2)
      elapsed = Time.now.to_i - start_time
      speed = processed_directories / elapsed.to_f             # entries per second
      remaining = total_directories - processed_directories
      eta_seconds = (remaining / speed).round      # estimated time left
      eta = Time.at(eta_seconds).utc.strftime("%H:%M:%S")
      
      line = "⏱️  Processed: #{processed_directories}/#{total_directories} (#{percent}%) | Elapsed: #{elapsed}s | Speed: #{speed.round(2)}/s | ETA: ~#{eta}"
      print "\r#{line.ljust(120)}"
      $stdout.flush
    end
  end

  def generate_fingerprint(site)
    random_path = "#{site}/nonexistent_#{rand(100000..999999)}"
    response = HTTPX.get(random_path)
  
    return nil unless response.is_a?(HTTPX::Response) && response.status.to_s.start_with?("2")
  
    #puts "\n -> Fingerprint size: #{response.body.to_s.size} bytes\n"
    response.body.to_s.size
  end
  
  def false_positive?(response, fingerprint, tolerance = 100)
    return false unless response && response.body    
    (response.body.to_s.size - fingerprint).abs <= tolerance
  end
  
end
