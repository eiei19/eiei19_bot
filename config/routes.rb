Rails.application.routes.draw do
  root 'callback#index'
  post "/callback" => "callback#index"
end