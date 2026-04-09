require "test_helper"
require "fileutils"

class DownloadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @redis = FakeRedis.new
    @original_redis = REDIS
    Object.send(:remove_const, :REDIS)
    Object.const_set(:REDIS, @redis)
    FileUtils.mkdir_p(ScreenshotZipper.screenshots_dir)
  end

  teardown do
    FileUtils.rm_rf(ScreenshotZipper.screenshots_dir)
    Object.send(:remove_const, :REDIS)
    Object.const_set(:REDIS, @original_redis)
  end

  test "screenshot_zip_info returns false when zip password is missing" do
    get "/download/screenshot_zip_info", params: { site: "https://example.com" }

    assert_response :success
    assert_equal false, response.parsed_body["zip_ready"]
  end

  test "screenshot_zip_info returns password when zip is ready" do
    site = "https://example.com"
    zip_path = ScreenshotZipper.screenshots_dir.join("#{ScreenshotZipper.stripped_site(site)}.zip")
    File.write(zip_path, "zip")
    @redis.set_string("screenshot_zip_password_#{site}", "secret123")

    get "/download/screenshot_zip_info", params: { site: site }

    assert_response :success
    assert_equal true, response.parsed_body["zip_ready"]
    assert_equal "secret123", response.parsed_body["password"]
  end

  test "screenshot_zip returns not found when zip file does not exist" do
    get "/download/screenshot_zip", params: { site: "https://example.com" }

    assert_response :not_found
    assert_equal "ZIP file not ready", response.parsed_body["error"]
  end
end
