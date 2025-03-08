class ScansController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create] 

  def create
    site = params[:site]

    if site.blank?
      render json: { error: "Site URL is required" }, status: :unprocessable_entity
      return
    end

    ScanWorker.perform_async(site)

    render json: { message: "Scan started for #{site}" }, status: :accepted
  end
end
