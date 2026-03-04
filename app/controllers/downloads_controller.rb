class DownloadsController < ApplicationController
  def screenshot_zip
    site = normalize_site(params[:site])
    sitestrip = ScreenshotZipper.stripped_site(site)
    zip_path = ScreenshotZipper.screenshots_dir.join("#{sitestrip}.zip")

    unless File.exist?(zip_path)
      render json: { error: "ZIP file not ready" }, status: :not_found and return
    end

    password = REDIS.get("screenshot_zip_password_#{site}")

    send_file zip_path,
              filename: "#{sitestrip}_screenshots.zip",
              type: "application/zip",
              disposition: "attachment"
  end

  def screenshot_zip_info
    site = normalize_site(params[:site])
    sitestrip = ScreenshotZipper.stripped_site(site)
    zip_path = ScreenshotZipper.screenshots_dir.join("#{sitestrip}.zip")
    password = REDIS.get("screenshot_zip_password_#{site}")
    screenshot_complete = REDIS.get("screenshot_scan_complete_#{site}") == "true"

    if screenshot_complete && (!password.present? || !File.exist?(zip_path))
      generated_password = ScreenshotZipper.zip(site)
      password = generated_password if generated_password.present?
    end

    if password.present? && File.exist?(zip_path)
      render json: { zip_ready: true, password: password }
    else
      render json: { zip_ready: false }
    end
  end

  private

  def normalize_site(raw_site)
    raw_site.to_s.strip.chomp("/")
  end
end
