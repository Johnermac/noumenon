Rails.application.routes.draw do
  #resources :scans, only: [:create]
  root "home#index" 

  post 'scans/create', to: 'scans#create'
  
  get 'scans/show', to: 'scans#show' 
  get "/download/screenshot_zip", to: "downloads#screenshot_zip"
  get "/download/screenshot_zip_info", to: "downloads#screenshot_zip_info"

end
