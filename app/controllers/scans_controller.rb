class ScansController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create] 

  def create
    site = params[:site]
    scan_directories = params[:scan_directories] || false  # Default to false if not provided
    scan_subdomains = params[:scan_subdomains] || false

    puts "\n => Received scan_directories: #{scan_directories}" # Debug
    puts "\n => Received scan_subdomains: #{scan_subdomains}" # Debug


    if site.blank?
      render json: { error: "Site URL is required" }, status: :unprocessable_entity
      return
    end

    ScanWorker.perform_async(site, scan_directories, scan_subdomains)

    render json: { message: "Scan started for #{site}", scan_directories: scan_directories, scan_subdomains: scan_subdomains }, status: :accepted
  end

  def show
    site = params[:site]
    
    sub_results_json = REDIS.get("scan_results_#{site}_subdomains")
    found_directories = REDIS.smembers("found_directories_#{site}")
    not_found_directories = REDIS.smembers("not_found_directories_#{site}")
    active_subdomains = REDIS.smembers("active_subdomains_#{site}")

    subdomain_scan_complete = REDIS.get("subdomain_scan_complete_#{site}") == "true"
    directories_scan_complete = REDIS.get("directories_scan_complete_#{site}") == "true"

    if found_directories.empty? && not_found_directories.empty? && sub_results_json.nil? && active_subdomains.empty?
      render json: { error: "No results found for #{site}" }, status: :not_found
      return
    end

    combined_results = {
      found_directories: found_directories,
      not_found_directories: not_found_directories,
      active_subdomains: active_subdomains,
      subdomain_scan_complete: subdomain_scan_complete,
      directories_scan_complete: directories_scan_complete
    }

    render json: combined_results
  end
end
