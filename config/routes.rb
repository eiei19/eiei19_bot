Rails.application.routes.draw do
  root 'callback#index'
  get "/facebook" => "callback#facebook"
  post "/facebook" => "callback#facebook"
  post "/line" => "callback#line"
end