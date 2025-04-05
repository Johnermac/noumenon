require "httparty"
require "watir"
require "zip"

class ScreenshotsWorker
  include Sidekiq::Worker

  def perform(url, site, total_urls)
    begin         
      response = HTTParty.get(url, headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" })


      if response.success?
        browser = Watir::Browser.new :firefox, headless: true
        browser.goto(url)

        # DIR TO SAVE SCREENSHOTS

        sitestrip = site.gsub(/https?:\/\/(www\.)?/, "").gsub(/(www\.)?/, "")
        output_dir = Rails.root.join("tmp", "screenshots", sitestrip)
        FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

        sleep 5        

        filename = url.gsub(%r{https?://}, '').gsub(/[^\w\-]+/, '_').gsub(/^_+|_+$/, '') + '.png'

        path = File.join(output_dir, filename)
        browser.screenshot.save(path)

        #REDIS.sadd("screenshots_#{site}", url) unless url.empty?
        puts "---> Screenshot taken from #{url}: #{url.size}"

        
      else
        puts "Failed to fetch URL: #{url} - Response Code: #{response.code}"
      end            
    rescue StandardError => e
      puts "Error during screenshot: #{e.message}"    
    ensure
      browser&.close
      # Track the total number of screenshots processed
      REDIS.incrby("processed_screenshots_#{site}", 1)

      # Check the number of completed screenshots
      processed_screenshots = REDIS.get("processed_screenshots_#{site}").to_i
      puts "---> processed screenshots: #{processed_screenshots}/#{total_urls}"      
      REDIS.set("screenshot_scan_complete_#{site}", "true") if processed_screenshots >= total_urls
    end

    # ---------------------------- CLEANUP ----------------------------------------

    REDIS.expire("processed_screenshots_#{site}", 300)
    REDIS.expire("screenshots_scan_complete_#{site}", 300)

    puts "\n  Screenshots for #{url}:"
    puts "    \t✅ Screenshot: #{url}" unless url.to_s.empty?

  end
end
