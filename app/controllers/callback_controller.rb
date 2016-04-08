class CallbackController < ApplicationController
  protect_from_forgery with: :null_session

  def index
    channel_secret = ENV["LINE_CHANNEL_SECRET"]
    http_request_body = request.raw_post
    hash = OpenSSL::HMAC::digest(OpenSSL::Digest::SHA256.new, channel_secret, http_request_body)
    signature = Base64.strict_encode64(hash)
    p signature
    p request.headers["X-LINE-CHANNELSIGNATURE"]
    render json: [], status: :ok
  end
end
