class ScansController < ApplicationController
  def new
    # Show scan form (if using a UI)
  end

  def create
    # Handle scan request
    domain = params[:domain]
    options = params[:options] # e.g., directories, subdomains, stealth mode

    # Trigger a background job
    ScanJob.perform_async(domain, options)

    render json: { message: "Scan started", domain: domain }
  end

  def show
    @scan = Scan.find(params[:id])
    render json: @scan
  end
end
