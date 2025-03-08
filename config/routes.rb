Rails.application.routes.draw do
  resources :scans, only: [:new, :create, :show]
end
