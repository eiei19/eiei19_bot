class CallbackController < ApplicationController
  protect_from_forgery with: :null_session

  def index
    render json: [], status: :ok
  end

  def line
    ## ちゃんとLINEから来たリクエストか署名で検証する
    channel_secret = ENV["LINE_CHANNEL_SECRET"]
    http_request_body = request.raw_post
    hash = OpenSSL::HMAC::digest(OpenSSL::Digest::SHA256.new, channel_secret, http_request_body)
    signature = Base64.strict_encode64(hash)
    if signature != request.headers["X-LINE-CHANNELSIGNATURE"]
      render json: [], status: :ng
      return
    end

    ## だれからのメッセージかとその内容
    from = params[:result][0][:content][:from]
    text = params[:result][0][:content][:text]

    ## 翻訳結果をメッセージ
    translated = translate(text)
    line_messaging(from, translated)
    render json: [], status: :ok
  end

  def facebook

    case request.request_method
    when "GET"
      render json: params["hub.challenge"], status: :ok

    when "POST"
      request_headers = {"Content-Type": "application/json"}
      params[:entry].each do |ent|
        ent[:messaging].each do |message|
          res = JSON.parse(RestClient.get(URI.encode("https://api.photozou.jp/rest/search_public.json?keyword=#{message[:message][:text]}&limit=3")))
          elements = []
          res["info"]["photo"].each.with_index(1) do |photo, index|
            elements << {
              title: "「#{message[:message][:text]}」の検索結果#{index}",
              image_url: photo["image_url"],
              buttons: [
                {
                  type: "web_url",
                  url: photo["url"],
                  title: "View Web Page",
                }
              ]
            }
          end
          message_data = {
            attachment: {
              type: "template",
              payload: {
                template_type: "generic",
                elements: elements
              }
            }
          }
          request_params = {
            recipient: {id: message[:sender][:id]},
            message: message_data
          }
          RestClient.post "https://graph.facebook.com/v2.6/me/messages?access_token=#{ENV["SERVICE_SAFARI_PAGE_TOKEN"]}", request_params.to_json, request_headers
        end
      end
      render json: [], status: :ok

    end
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
        toChannel: 1383378250, # この値はFIXらしいです
        eventType: "138311608800106203", # この値はFIXらしいです
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
