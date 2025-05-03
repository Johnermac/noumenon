require "watir"
require "fileutils"
require "zip"

class ScreenshotsWorker
  include Sidekiq::Worker

  SCREENSHOT_EXPIRY = 300

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
          '--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0'
        ]
      }

      sitestrip = site.gsub(%r{https?://(www\.)?}, "").gsub(/(www\.)?/, "")
      output_dir = Rails.root.join("tmp", "screenshots", sitestrip)
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

      urls.each do |url|
        take_screenshot_for_url(browser, url, output_dir, site, urls.length)
      end

    rescue => e
      puts "❌ Fatal error in ScreenshotsWorker for #{site}: #{e.message}"

    ensure
      browser&.close rescue nil
      processed = REDIS.get("processed_screenshots_#{site}").to_i
      cleanup_screenshot(site) if processed >= urls.length
    end
  end

  private

  def take_screenshot_for_url(browser, url, output_dir, site, total_urls)
    begin
      retries = 0
      begin
        browser.goto(url)
      rescue => e
        retries += 1
        if retries < 2
          puts "Retrying #{url}... #{e.message}"          
          retry
        else
          raise
        end
      end

      browser.body.wait_until(timeout: 5, &:present?)

      filename = sanitized_filename(url)
      path = File.join(output_dir, filename)
      browser.screenshot.save(path)

      browser.goto("about:blank")

      puts "---> Screenshot saved for #{url} to #{path}"

    rescue Selenium::WebDriver::Error::TimeoutError => e
      puts "❌ Page load timeout for #{url}: #{e.message} - Skipping"

    rescue StandardError => e
      puts "❌ General screenshot error for #{url}: #{e.message} - Skipping"

    ensure
      REDIS.incrby("processed_screenshots_#{site}", 1)
      processed = REDIS.get("processed_screenshots_#{site}").to_i
      puts "---> Processed screenshots: #{processed}/#{total_urls}"
    end
  end

  def sanitized_filename(url)
    basename = url.gsub(%r{https?://}, '')
                  .gsub(/[^\w\-]+/, '_')
                  .gsub(/^_+|_+$/, '')
                  .downcase    
    "#{basename}.png"
  end

  def cleanup_screenshot(site)
    REDIS.set("screenshot_scan_complete_#{site}", "true")
    REDIS.expire("processed_screenshots_#{site}", SCREENSHOT_EXPIRY)
    REDIS.expire("screenshot_scan_complete_#{site}", SCREENSHOT_EXPIRY)

    ScreenshotZipper.zip(site)
    CleanupScreenshotsFolderWorker.perform_in(5.minutes, site)

    puts "\n\t✅ All screenshots complete for #{site}"
  end
end
