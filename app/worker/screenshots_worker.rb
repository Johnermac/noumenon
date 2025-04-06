require "watir"
require "fileutils"

class ScreenshotsWorker
  include Sidekiq::Worker

  def perform(urls, site)
    browser = nil

    begin
      browser = Watir::Browser.new :firefox, headless: true

      sitestrip = site.gsub(%r{https?://(www\.)?}, "").gsub(/(www\.)?/, "")
      output_dir = Rails.root.join("tmp", "screenshots", sitestrip)
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

      urls.each do |url|
        begin
          browser.goto(url)
          sleep 5

          filename = url.gsub(%r{https?://}, '')
                        .gsub(/[^\w\-]+/, '_')
                        .gsub(/^_+|_+$/, '')
                        .downcase + '.png'

          path = File.join(output_dir, filename)
          browser.screenshot.save(path)

          puts "---> Screenshot saved for #{url}"
        rescue => e
          puts "❌ Screenshot error for #{url}: #{e.message}"
        end
      end

    rescue => e
      puts "❌ Error during screenshot process: #{e.message}"

    ensure
      browser&.close

      # Mark scan complete for this site
      REDIS.set("screenshot_scan_complete_#{site}", "true")
      REDIS.expire("screenshot_scan_complete_#{site}", 300)

      CleanupScreenshotsFolderWorker.perform_in(5.minutes, site)

      puts "\n\t✅ All screenshots complete for #{site}"
    end
  end
end
