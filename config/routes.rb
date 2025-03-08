Rails.application.routes.draw do
  resources :scans, only: [:create]
end
