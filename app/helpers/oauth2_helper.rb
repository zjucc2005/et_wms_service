# encoding: utf-8
module EtWmsService
  class App
    module Oauth2Helper
      def respond_oauth2(status, header, response)
        ['WWW-Authenticate'].each do |key|
          headers[key] = header[key] if header[key].present?
        end
        if response.redirect?
          redirect header['Location']
        else
          render 'oauth2/authorize'
        end
      end

    end

    helpers Oauth2Helper
  end
end