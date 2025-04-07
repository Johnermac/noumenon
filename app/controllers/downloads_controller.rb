class DownloadsController < ApplicationController
  def screenshot_zip
    site = params[:site]
    sitestrip = site.gsub(%r{https?://(www\.)?}, "").gsub(/(www\.)?/, "")
    zip_path = Rails.root.join("tmp", "screenshots", "#{sitestrip}.zip")

    unless File.exist?(zip_path)
      render json: { error: "ZIP file not ready" }, status: :not_found and return
    end

    password = REDIS.get("screenshot_zip_password_#{site}")

    send_file zip_path,
              filename: "#{sitestrip}_screenshots.zip",
              type: "application/zip",
              disposition: "attachment",
              x_sendfile: true
  end

  def screenshot_zip_info
    site = params[:site]
    password = REDIS.get("screenshot_zip_password_#{site}")
    if password
      render json: { zip_ready: true, password: password }
    else
      render json: { zip_ready: false }
    end
  end
end
