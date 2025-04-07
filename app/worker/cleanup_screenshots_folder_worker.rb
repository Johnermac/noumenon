class CleanupScreenshotsFolderWorker
  include Sidekiq::Worker

  def perform(site)   
    ScreenshotZipper.delete_zip(site)
  end  
end
