Rails.application.routes.draw do
  root 'callback#index'
  post "/callback" => "index#contact"
end