class CleanupScreenshotsFolderWorker
  include Sidekiq::Worker

  def perform(site)
    sitestrip = site.gsub(/https?:\/\/(www\.)?/, "").gsub(/(www\.)?/, "")
    folder_path = Rails.root.join("tmp", "screenshots", sitestrip)

    if Dir.exist?(folder_path)
      FileUtils.rm_rf(folder_path)
      puts "\n\t🧹 Deleted screenshots folder for #{site}"
    else
      puts "\n\t⚠️ Folder not found for #{site}"
    end
  end
end
