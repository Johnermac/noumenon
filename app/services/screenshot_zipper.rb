# app/services/screenshot_zipper.rb
require 'securerandom'
require 'shellwords'

class ScreenshotZipper
  def self.zip(site)
    sitestrip = stripped_site(site)
    screenshots_root = screenshots_dir
    FileUtils.mkdir_p(screenshots_root)
    zip_path = screenshots_root.join("#{sitestrip}.zip")
    password = SecureRandom.hex(16)
    folder_path = screenshots_root.join(sitestrip)

    return nil unless Dir.exist?(folder_path)

    FileUtils.rm_f(zip_path) if File.exist?(zip_path)

    zip_success = false
    Dir.chdir(screenshots_root) do
      zip_success = system("zip -r -P #{password} #{Shellwords.escape(zip_path.to_s)} #{Shellwords.escape(sitestrip)}")
    end
    return nil unless zip_success && File.exist?(zip_path)

    puts "\n\n\t📦 Zipped   : #{site}"
    puts "\t🔐 Password : #{password}\n\n"

    REDIS.set("screenshot_zip_password_#{site}", password)
    REDIS.expire("screenshot_zip_password_#{site}", 1800)    

    password

  end

  def self.delete_zip(site)
    sitestrip = stripped_site(site)
    root = screenshots_dir
    zip_path = root.join("#{sitestrip}.zip")
    folder_path = root.join(sitestrip)

    FileUtils.rm_f(zip_path) if File.exist?(zip_path)
    FileUtils.rm_rf(folder_path) if Dir.exist?(folder_path)

    puts "\n\t🧹 Deleted screenshots folder for #{site}"  
    
  end

  def self.stripped_site(site)
    site.to_s.gsub(%r{https?://(www\.)?}, "").gsub(/(www\.)?/, "")
  end

  def self.screenshots_dir
    Rails.root.join("tmp", "screenshots")
  end
end
