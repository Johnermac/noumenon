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
    scan_results_json = REDIS.get("scan_results_#{site}_directories")

    if scan_results_json.nil?
      render json: { error: "No results found for #{site}" }, status: :not_found
      return
    end

    scan_results = JSON.parse(scan_results_json)
    render json: scan_results
  end
end
