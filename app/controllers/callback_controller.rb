class CallbackController < ApplicationController
  protect_from_forgery with: :null_session

  def index
    channel_secret = ENV["LINE_CHANNEL_SECRET"]
    http_request_body = request.raw_post
    hash = OpenSSL::HMAC::digest(OpenSSL::Digest::SHA256.new, channel_secret, http_request_body)
    signature = Base64.strict_encode64(hash)
    if signature != request.headers["X-LINE-CHANNELSIGNATURE"]
      render json: [], status: :ng
      return
    end
    from = params[:result][0][:content][:from]
    text = params[:result][0][:content][:text]
    translated = translate(text)
    line_messaging(from, translated)
    render json: [], status: :ok
  end

  private
    def line_messaging to, text
      RestClient.proxy = ENV["FIXIE_URL"]
      request_headers = {
        "Content-Type": "application/json",
        "X-Line-ChannelID": ENV["LINE_CHANNEL_ID"],
        "X-Line-ChannelSecret": ENV["LINE_CHANNEL_SECRET"],
        "X-Line-Trusted-User-With-ACL": ENV["LINE_CHANNEL_MID"]
      }
      request_params = {
        to: [to],
        toChannel: 1383378250,
        eventType: "138311608800106203",
        content:{
          contentType: 1,
          toType: 1,
          text: text
        }
      }
      RestClient.post 'https://trialbot-api.line.me/v1/events', request_params.to_json, request_headers
    end

    def translate text
      request_params = {
        client_id: ENV["MS_CLIENT_ID"],
        client_secret: ENV["MS_CLIENT_SECRET"],
        scope: "http://api.microsofttranslator.com",
        grant_type: "client_credentials"
      }
      res = RestClient.post 'https://datamarket.accesscontrol.windows.net/v2/OAuth2-13', request_params
      access_token = JSON.parse(res)["access_token"]

      request_params = {
        appId: "Bearer #{access_token}",
        from: "ja",
        to: "en",
        text: text
      }
      res = RestClient.get 'https://api.microsofttranslator.com//V2/Ajax.svc/Translate', params: request_params
      res.scan(/".*"/).first.gsub("\"", "")
    end

end
