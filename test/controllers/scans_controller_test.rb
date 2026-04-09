require "test_helper"

class ScansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @redis = FakeRedis.new
    @original_redis = REDIS
    Object.send(:remove_const, :REDIS)
    Object.const_set(:REDIS, @redis)
    ScanWorker.clear
  end

  teardown do
    ScanWorker.clear
    Object.send(:remove_const, :REDIS)
    Object.const_set(:REDIS, @original_redis)
  end

  def with_stubbed_reset_sidekiq
    original_method = ScansController.instance_method(:reset_sidekiq)
    ScansController.send(:define_method, :reset_sidekiq) { nil }
    yield
  ensure
    ScansController.send(:define_method, :reset_sidekiq, original_method)
  end

<<<<<<< HEAD
  def with_stubbed_valid_site(result)
    original_method = ScansController.instance_method(:valid_site?)
    ScansController.send(:define_method, :valid_site?) { |_site| result }
    yield
  ensure
    ScansController.send(:define_method, :valid_site?, original_method)
  end

  test "create returns unprocessable entity when site is missing" do
    with_stubbed_reset_sidekiq do
      with_stubbed_valid_site(true) do
        post "/scans/create", params: { scan_directories: true }
      end
=======
  test "create returns unprocessable entity when site is missing" do
    with_stubbed_reset_sidekiq do
      post "/scans/create", params: { scan_directories: true }
>>>>>>> e2c09e0 (B: test added to pipeline)
    end

    assert_response :unprocessable_entity
    assert_equal "Site URL is required", response.parsed_body["error"]
    assert_equal 0, ScanWorker.jobs.size
  end

  test "create enqueues scan and disables screenshots when feature is off" do
    with_stubbed_reset_sidekiq do
<<<<<<< HEAD
      with_stubbed_valid_site(true) do
        original_value = ENV["SCREENSHOT_ENABLED"]
        ENV["SCREENSHOT_ENABLED"] = "false"
        begin
          post "/scans/create", params: {
            site: "https://example.com",
            scan_directories: "true",
            scan_subdomains: "false",
            scan_links: "true",
            scan_emails: "false",
            scan_screenshots: "true"
          }
        ensure
          ENV["SCREENSHOT_ENABLED"] = original_value
        end
=======
      original_value = ENV["SCREENSHOT_ENABLED"]
      ENV["SCREENSHOT_ENABLED"] = "false"
      begin
        post "/scans/create", params: {
          site: "https://example.com",
          scan_directories: "true",
          scan_subdomains: "false",
          scan_links: "true",
          scan_emails: "false",
          scan_screenshots: "true"
        }
      ensure
        ENV["SCREENSHOT_ENABLED"] = original_value
>>>>>>> e2c09e0 (B: test added to pipeline)
      end
    end

    assert_response :accepted
    assert_equal false, response.parsed_body["screenshot_feature_enabled"]
    assert_equal 1, ScanWorker.jobs.size
    assert_equal [
      "https://example.com",
<<<<<<< HEAD
      true,
      false,
      true,
      false,
=======
      "true",
      "false",
      "true",
      "false",
>>>>>>> e2c09e0 (B: test added to pipeline)
      false
    ], ScanWorker.jobs.first["args"]
  end

  test "show returns not found when scan is complete and no results exist" do
    site = "https://example.com"
    @redis.set_string("subdomain_scan_complete_#{site}", "true")
    @redis.set_string("directories_scan_complete_#{site}", "true")
    @redis.set_string("link_scan_complete_#{site}", "true")
    @redis.set_string("email_scan_complete_#{site}", "true")
    @redis.set_string("screenshot_scan_complete_#{site}", "true")

    get "/scans/show", params: { site: site }

<<<<<<< HEAD
    assert_response :success
    assert_equal [], response.parsed_body["found_subdomains"]
    assert_equal [], response.parsed_body["found_directories"]
    assert_equal [], response.parsed_body["not_found_directories"]
    assert_equal [], response.parsed_body["active_subdomains"]
    assert_equal [], response.parsed_body["extracted_links"]
    assert_equal [], response.parsed_body["extracted_emails"]
    assert_equal(
      {
        "scan_directories" => false,
        "scan_subdomains" => false,
        "scan_links" => false,
        "scan_emails" => false,
        "scan_screenshots" => false
      },
      response.parsed_body["scan_options"]
    )
=======
    assert_response :not_found
    assert_equal "No results found for #{site}", response.parsed_body["error"]
>>>>>>> e2c09e0 (B: test added to pipeline)
  end

  test "show returns combined results with unique links and emails" do
    site = "https://example.com"
    @redis.add_set("found_directories_#{site}", "/admin")
    @redis.add_set("not_found_directories_#{site}", "/missing")
<<<<<<< HEAD
    @redis.set_string("scan_results_#{site}_subdomains", { found_subdomains: ["api.example.com"] }.to_json)
    @redis.add_set("active_subdomains_#{site}", "api.example.com")
    @redis.add_set("links_#{site}", "https://example.com/about", "https://example.com/about")
    @redis.add_set("emails_#{site}", "admin@example.com", "admin@example.com")
    @redis.set_string(
      "scan_options_#{site}",
      {
        scan_directories: true,
        scan_subdomains: true,
        scan_links: true,
        scan_emails: true,
        scan_screenshots: false
      }.to_json
    )
=======
    @redis.set_string("scan_results_#{site}_subdomains", "api.example.com")
    @redis.add_set("active_subdomains_#{site}", "api.example.com")
    @redis.add_set("links_#{site}", "https://example.com/about", "https://example.com/about")
    @redis.add_set("emails_#{site}", "admin@example.com", "admin@example.com")
>>>>>>> e2c09e0 (B: test added to pipeline)

    get "/scans/show", params: { site: site }

    assert_response :success
<<<<<<< HEAD
    assert_equal ["api.example.com"], response.parsed_body["found_subdomains"]
    assert_equal ["/admin"], response.parsed_body["found_directories"]
    assert_equal ["/missing"], response.parsed_body["not_found_directories"]
    assert_equal ["api.example.com"], response.parsed_body["active_subdomains"]
    assert_equal ["https://example.com/about"], response.parsed_body["extracted_links"]
    assert_equal ["admin@example.com"], response.parsed_body["extracted_emails"]
    assert_equal true, response.parsed_body["scan_options"]["scan_directories"]
    assert_equal true, response.parsed_body["scan_options"]["scan_subdomains"]
=======
    assert_equal ["/admin"], response.parsed_body["found_directories"]
    assert_equal ["/missing"], response.parsed_body["not_found_directories"]
    assert_equal "api.example.com", response.parsed_body["found_subdomains"]
    assert_equal ["api.example.com"], response.parsed_body["active_subdomains"]
    assert_equal ["https://example.com/about"], response.parsed_body["extracted_links"]
    assert_equal ["admin@example.com"], response.parsed_body["extracted_emails"]
>>>>>>> e2c09e0 (B: test added to pipeline)
  end
end
