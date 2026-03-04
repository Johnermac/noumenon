require 'sidekiq/api'
require 'json'

class ScansController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create] 

  def create

    reset_sidekiq()

    site = normalize_site(params[:site])
    scan_directories = cast_bool(params[:scan_directories])
    scan_subdomains = cast_bool(params[:scan_subdomains])
    scan_links = cast_bool(params[:scan_links])
    scan_emails = cast_bool(params[:scan_emails])
    scan_screenshots = cast_bool(params[:scan_screenshots])
    scan_screenshots = false unless screenshot_feature_enabled?

    if site.blank?
      render json: { error: "Site URL is required" }, status: :unprocessable_entity
      return
    end

    ScanWorker.perform_async(site, scan_directories, scan_subdomains, scan_links, scan_emails, scan_screenshots)

    render json: {
      message: "Scan started for #{site}",
      scan_directories: scan_directories,
      scan_subdomains: scan_subdomains,
      scan_links: scan_links,
      scan_emails: scan_emails,
      scan_screenshots: scan_screenshots,
      screenshot_feature_enabled: screenshot_feature_enabled?
    }, status: :accepted
  end

  def show
    site = normalize_site(params[:site])
    scan_options = parse_scan_options(REDIS.get("scan_options_#{site}"))

    # ---------- DIRECTORIES ---------

    found_directories = REDIS.smembers("found_directories_#{site}")
    not_found_directories = REDIS.smembers("not_found_directories_#{site}")    

    # ---------- SUBDOMAINS ----------

    active_subdomains = REDIS.smembers("active_subdomains_#{site}")
    found_subdomains_raw = REDIS.get("scan_results_#{site}_subdomains")
    found_subdomains = parse_found_subdomains(found_subdomains_raw)

    # ---------- LINKS ---------------

    extracted_links = REDIS.smembers("links_#{site}")

    # ---------- EMAILS ---------------

    extracted_emails = REDIS.smembers("emails_#{site}")   


    # ---------- STATUS --------------

    subdomain_scan_complete = REDIS.get("subdomain_scan_complete_#{site}") == "true"
    directories_scan_complete = REDIS.get("directories_scan_complete_#{site}") == "true"
    link_scan_complete = REDIS.get("link_scan_complete_#{site}") == "true"
    email_scan_complete = REDIS.get("email_scan_complete_#{site}") == "true"
    screenshot_scan_complete = REDIS.get("screenshot_scan_complete_#{site}") == "true"
    screenshot_scan_error = REDIS.get("screenshot_scan_error_#{site}")

    # ---------- DIRECTORY TELEMETRY --------------

    directory_telemetry = nil
    if scan_options["scan_directories"]
      current_directory_phase = REDIS.get("directories_scan_phase_#{site}")
      phase_total = REDIS.get("directories_scan_phase_total_#{site}").to_i
      phase_processed = 0
      if current_directory_phase.present? && current_directory_phase != "completed"
        phase_processed = REDIS.get("processed_directories_#{site}_#{current_directory_phase}").to_i
      end

      phase_hit_rates = begin
        JSON.parse(REDIS.get("directories_phase_hit_rates_#{site}") || "{}")
      rescue JSON::ParserError
        {}
      end

      waf_detected = REDIS.get("directories_waf_detected_#{site}") == "true"
      directory_scan_error = REDIS.get("directories_scan_error_#{site}")

      directory_telemetry = {
        current_phase: current_directory_phase || (directories_scan_complete ? "completed" : "starting"),
        phase_processed: phase_processed,
        phase_total: phase_total,
        phase_hit_rates: phase_hit_rates,
        waf_detected: waf_detected,
        scan_error: directory_scan_error
      }
    end

    combined_results = {
      found_subdomains: found_subdomains,
      found_directories: found_directories,
      not_found_directories: not_found_directories,
      active_subdomains: active_subdomains,
      extracted_links: extracted_links.uniq,
      extracted_emails: extracted_emails.uniq,
      scan_options: scan_options,
      subdomain_scan_complete: subdomain_scan_complete,
      directories_scan_complete: directories_scan_complete,
      link_scan_complete: link_scan_complete,
      email_scan_complete: email_scan_complete,
      screenshot_scan_complete: screenshot_scan_complete,
      screenshot_scan_error: screenshot_scan_error,
      directory_telemetry: directory_telemetry
    }    


    render json: combined_results
  end  

  def reset_sidekiq       
    puts "🧹 Clearing all Sidekiq jobs..."
    Sidekiq::Queue.all.each(&:clear)
    Sidekiq::ScheduledSet.new.clear
    Sidekiq::RetrySet.new.clear
    Sidekiq::DeadSet.new.clear    
  end

  private

  def normalize_site(raw_site)
    raw_site.to_s.strip.chomp("/")
  end

  def parse_found_subdomains(raw)
    return [] if raw.blank?

    parsed = JSON.parse(raw)
    Array(parsed["found_subdomains"]).uniq
  rescue JSON::ParserError, TypeError
    []
  end

  def parse_scan_options(raw)
    default_options = {
      "scan_directories" => false,
      "scan_subdomains" => false,
      "scan_links" => false,
      "scan_emails" => false,
      "scan_screenshots" => false
    }
    return default_options if raw.blank?

    parsed = JSON.parse(raw)
    default_options.merge(parsed)
  rescue JSON::ParserError, TypeError
    default_options
  end

  def cast_bool(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
