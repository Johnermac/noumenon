# app/services/screenshot_zipper.rb
require 'securerandom'
require 'shellwords'

class ScreenshotZipper
  def self.zip(site)
    sitestrip = site.gsub(%r{https?://(www\.)?}, "").gsub(/(www\.)?/, "")
    screenshots_root = Rails.root.join("tmp", "screenshots")
    zip_path = screenshots_root.join("#{sitestrip}.zip")
    password = SecureRandom.hex(16)

    Dir.chdir(screenshots_root) do
      system("zip -r -P #{password} #{Shellwords.escape(zip_path.to_s)} #{Shellwords.escape(sitestrip)}")
    end

    puts "\n\n\t📦 Zipped   : #{site}"
    puts "\t🔐 Password : #{password}\n\n"

    REDIS.set("screenshot_zip_password_#{site}", password)
    REDIS.expire("screenshot_zip_password_#{site}", 300)    

    # delete folder right away
    folder_path = Rails.root.join("tmp", "screenshots", sitestrip)
    FileUtils.rm_rf(folder_path) if Dir.exist?(folder_path)

  end

  def self.delete_zip(site)
    sitestrip = site.gsub(/https?:\/\/(www\.)?/, "").gsub(/(www\.)?/, "")    
    zip_path = Rails.root.join("tmp", "screenshots", "#{sitestrip}.zip")

    FileUtils.rm_f(zip_path) if File.exist?(zip_path)

    puts "\n\t🧹 Deleted screenshots folder for #{site}"  
    
  end
end
