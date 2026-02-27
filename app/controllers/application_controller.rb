class ApplicationController < ActionController::Base
  helper_method :screenshot_feature_enabled?

  private

  def screenshot_feature_enabled?
    ENV.fetch("SCREENSHOT_ENABLED", "true") == "true"
  end
end
