class ScansController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create] 

  def create
    site = params[:site]
    scan_directories = params[:scan_directories] || false  # Default to false if not provided
    scan_subdomains = params[:scan_subdomains] || false
    scan_links = params[:scan_links] || false    
    scan_emails = params[:scan_emails] || false 
    scan_screenshots = params[:scan_screenshots] || false   

    if site.blank?
      render json: { error: "Site URL is required" }, status: :unprocessable_entity
      return
    end

    ScanWorker.perform_async(site, scan_directories, scan_subdomains, scan_links, scan_emails, scan_screenshots)

    render json: { message: "Scan started for #{site}", scan_directories: scan_directories, scan_subdomains: scan_subdomains }, status: :accepted
  end

  def show
    site = params[:site]

    # ---------- DIRECTORIES ---------

    found_directories = REDIS.smembers("found_directories_#{site}")
    not_found_directories = REDIS.smembers("not_found_directories_#{site}")    

    # ---------- SUBDOMAINS ----------

    active_subdomains = REDIS.smembers("active_subdomains_#{site}")
    found_subdomains = REDIS.get("scan_results_#{site}_subdomains")

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


    # ---------- VALIDATION ----------

    if subdomain_scan_complete && directories_scan_complete && link_scan_complete && email_scan_complete && screenshot_scan_complete &&
      found_directories.empty? && not_found_directories.empty? && found_subdomains.nil? &&
      active_subdomains.empty? && extracted_links.empty? && extracted_emails.empty?
        render json: { error: "No results found for #{site}" }, status: :not_found
        return
    end

    combined_results = {
      found_subdomains: found_subdomains,
      found_directories: found_directories,
      not_found_directories: not_found_directories,
      active_subdomains: active_subdomains,
      extracted_links: extracted_links.uniq,
      extracted_emails: extracted_emails.uniq,
      subdomain_scan_complete: subdomain_scan_complete,
      directories_scan_complete: directories_scan_complete,
      link_scan_complete: link_scan_complete,
      email_scan_complete: email_scan_complete,
      screenshot_scan_complete: screenshot_scan_complete     
    }    


    render json: combined_results
  end  
end
