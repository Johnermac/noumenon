require "watir"
require "fileutils"
require "zip"

class ScreenshotsWorker
  include Sidekiq::Worker

  SCREENSHOT_EXPIRY = 7200
  LOCK_TTL = 7200

  def perform(urls, site)
    lock_key = "screenshot_worker_lock_#{site}"
    unless acquire_lock(lock_key)
      puts "⚠️ Skipping duplicate ScreenshotsWorker for #{site}"
      return
    end

    REDIS.set("expected_screenshots_#{site}", urls.length)
    REDIS.expire("expected_screenshots_#{site}", SCREENSHOT_EXPIRY)

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

      sitestrip = ScreenshotZipper.stripped_site(site)
      output_dir = ScreenshotZipper.screenshots_dir.join(sitestrip)
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

      urls.each do |url|
        take_screenshot_for_url(browser, url, output_dir, site, urls.length)
      end

    rescue => e
      puts "❌ Fatal error in ScreenshotsWorker for #{site}: #{e.message}"

    ensure
      browser&.close rescue nil
      processed = REDIS.get("processed_screenshots_#{site}").to_i
      expected = REDIS.get("expected_screenshots_#{site}").to_i
      cleanup_screenshot(site) if expected.positive? && processed >= expected && mark_cleanup_once(site)
      release_lock(lock_key)
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
    REDIS.expire("processed_screenshots_#{site}", SCREENSHOT_EXPIRY)
    REDIS.expire("expected_screenshots_#{site}", SCREENSHOT_EXPIRY)

    password = ScreenshotZipper.zip(site)
    if password
      REDIS.set("screenshot_scan_complete_#{site}", "true")
      REDIS.expire("screenshot_scan_complete_#{site}", SCREENSHOT_EXPIRY)
      REDIS.del("screenshot_scan_error_#{site}")
      REDIS.del("screenshot_cleanup_started_#{site}")
      CleanupScreenshotsFolderWorker.perform_in(30.minutes, site)
      puts "\n\t✅ All screenshots complete for #{site}"
    else
      REDIS.set("screenshot_scan_complete_#{site}", "false")
      REDIS.set("screenshot_scan_error_#{site}", "zip_generation_failed")
      REDIS.expire("screenshot_scan_complete_#{site}", SCREENSHOT_EXPIRY)
      REDIS.expire("screenshot_scan_error_#{site}", SCREENSHOT_EXPIRY)
      puts "\n\t❌ Screenshot ZIP could not be created for #{site}"
    end
  end

  def acquire_lock(lock_key)
    REDIS.set(lock_key, jid, nx: true, ex: LOCK_TTL)
  end

  def release_lock(lock_key)
    return unless REDIS.get(lock_key) == jid
    REDIS.del(lock_key)
  end

  def mark_cleanup_once(site)
    REDIS.set("screenshot_cleanup_started_#{site}", jid, nx: true, ex: LOCK_TTL)
  end
end
