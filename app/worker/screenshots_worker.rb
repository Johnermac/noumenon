# sudo apt install chromium-driver

require "watir"
require "fileutils"

class ScreenshotsWorker
  include Sidekiq::Worker

  def perform(urls, site)
    browser = nil

    begin
      browser = Watir::Browser.new :chrome, options: {
        args: ['--disable-gpu', '--no-sandbox']
      }
        # '--headless', 
          

      sitestrip = site.gsub(%r{https?://(www\.)?}, "").gsub(/(www\.)?/, "")
      output_dir = Rails.root.join("tmp", "screenshots", sitestrip)
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

      urls.each do |url|        

        3.times do
          begin
            browser.goto(url)
            break
          rescue => e
            puts "Retrying... #{e.message}"
            sleep 2
          end
        end          
        
        sleep 10

        filename = url.gsub(%r{https?://}, '')
                      .gsub(/[^\w\-]+/, '_')
                      .gsub(/^_+|_+$/, '')
                      .downcase + '.png'

        path = File.join(output_dir, filename)
        browser.screenshot.save(path)

        browser.goto("about:blank")

        #puts "---> Screenshot saved for #{url}"

        REDIS.incrby("processed_screenshots_#{site}", 1)
        processed_screenshots = REDIS.get("processed_screenshots_#{site}").to_i
        puts "---> processed screenshot: #{processed_screenshots}/#{urls.length}" 
       
      end

    rescue => e
      puts "❌ Screenshot error for #{url}: #{e.message}"

    ensure
      processed_screenshots = REDIS.get("processed_screenshots_#{site}").to_i
      if processed_screenshots >= urls.length

        browser&.close        
        REDIS.set("screenshot_scan_complete_#{site}", "true")
        REDIS.expire("processed_screenshots_#{site}", 300)
        REDIS.expire("screenshot_scan_complete_#{site}", 300)
        CleanupScreenshotsFolderWorker.perform_in(5.minutes, site)

        puts "\n\t✅ All screenshots complete for #{site}"
      end
    end
  end
end
