Rails.application.routes.draw do
  #resources :scans, only: [:create]
  post 'scans/create', to: 'scans#create'
  get 'scans/show', to: 'scans#show'
  root "home#index" 
end
