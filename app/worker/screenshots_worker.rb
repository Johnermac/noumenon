# sudo apt install chromium-driver

require "watir"
require "fileutils"
require "zip"

class ScreenshotsWorker
  include Sidekiq::Worker

  def perform(urls, site)
    browser = nil

    begin
      browser = Watir::Browser.new :chrome, options: {
        args: [
          '--headless',
          '--disable-gpu',
          '--no-sandbox',
          '--window-size=1280,720',
          '--disable-blink-features=AutomationControlled',          
          '--disable-dev-shm-usage',
          '--ignore-certificate-errors',
          '--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36'
        ]
      }        
          

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
        
        #sleep 5
        # Check if page finished loading
        browser.body.wait_until(&:present?)

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
        cleanup_screenshot(site)
      end
    end
  end

  private

  def cleanup_screenshot(site)
    REDIS.set("screenshot_scan_complete_#{site}", "true")
    REDIS.expire("processed_screenshots_#{site}", 300)
    REDIS.expire("screenshot_scan_complete_#{site}", 300)    

    ScreenshotZipper.zip(site)
    CleanupScreenshotsFolderWorker.perform_in(5.minutes, site)

    puts "\n\t✅ All screenshots complete for #{site}"
  end

  

end
