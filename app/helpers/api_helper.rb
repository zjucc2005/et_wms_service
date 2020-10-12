# encoding: utf-8
# ApiHelper 主要用于定义全局使用的helper方法, 包括 error catch, 参数加载, token 认证等
module EtWmsService
  class App
    module ApiHelper

      def api_rescue
        begin
          block_given? ? yield : raise('no block given')
        rescue Exception => e
          logger.info "FAIL #{request.path} - #{e.message}" unless Padrino.env == :production
          { status: 'fail', reason: [ e.message ] }.to_json
        end
      end

      def load_api_request_params
        request.body.rewind
        request_body_read = request.body.read
        logger.info "request body: #{request_body_read}"
        @request_params = JSON.parse(request_body_read) rescue params
      end

      def authenticate_access_token
        access_token = AccessToken.valid.find_by_token(params['access_token'] || @request_params.try(:[], 'access_token'))
        if access_token && access_token.account
          @request_account = access_token.account
        else
          raise t('api.errors.invalid_access_token')
        end
      end

    end

    helpers ApiHelper
  end
end