# encoding: utf-8
EtWmsService::App.controllers :oauth2 do
  # -----------------------------------------------------------------
  # Oauth2.0 Server Implementation(Oauth 2.0 protocol)

  # authorize request params
  # 1. :response_type => %w(code token), 请求类型
  # 2. :client_id,                       请求方身份识别码
  # 3. :redirect_uri(required),          用于认证完毕后重定向
  # 4. :scope(optional),                 授权列表, 暂时不需要

  # token request params
  # 1. :grant_type => %w(authorization_code password client_credentials refresh_token)
  # 2. :client_id
  # 3. :client_secret
  # 下面 3 选 1
  # 4. :code                 (grant_type: authorization_code)
  # 5. :username & :password (grant_type: password)
  # 6. :refresh_token        (grant_type: refresh_token)

  # return json
  # {
  #    :access_token  => 'tGzv3JOkF0XG5Qx2TlKWIA...',
  #    :refresh_token => 'LCsRYEltZAQBbzFXPRzxxL...',  # optional
  #    :token_type    => 'bearer',
  #    :expires_in    => 86400,
  # }
  # -----------------------------------------------------------------
  get :authorize do
    authorization_endpoint = Rack::OAuth2::Server::Authorize.new do |req, res|
      @client = Client.find_by(identifier: req.client_id)
      req.bad_request! if @client.blank?
      res.redirect_uri = req.redirect_uri
      # 如果需要对 redirect_uri 进行验证, 请用下方代码替换
      # res.redirect_uri = req.verify_redirect_uri!(@client.redirect_uri)
      @redirect_uri  = res.redirect_uri
      @response_type = req.response_type

      case req.response_type
        when :code
          # render 'oauth2/authorize'
          # 如果已有用户登录, 直接返回authorization_code
          if logged_in?
            current_authorization_code = current_account.authorization_codes.valid.where(:client_id => @client.id).first
            authorization_code = current_authorization_code || current_account.authorization_codes.create(:client => @client, :redirect_uri => @redirect_uri )
            res.code = authorization_code.token
            res.approve!
          end
        when :token
          # render 'oauth2/authorize'
          # 如果已有用户登录, 直接返回access_token
          if logged_in?
            current_access_token = current_account.access_tokens.valid.where(:client_id => @client.id).first
            access_token = current_access_token || current_account.access_tokens.create(:client => @client)
            res.access_token = access_token.to_bearer_token
            res.approve!
          end
        else
          req.unsupported_response_type!
      end
    end
    respond_oauth2 *authorization_endpoint.call(request.env)
  end

  post :authorize do
    # 用户登录认证
    account = Account.authenticate(params[:email], params[:password])
    if account
      set_current_account(account)

      authorization_endpoint = Rack::OAuth2::Server::Authorize.new do |req, res|
        @client = Client.find_by(identifier: req.client_id)
        req.bad_request! if @client.blank?
        res.redirect_uri = req.redirect_uri
        # 如果需要对 redirect_uri 进行验证, 请用下方代码替换
        # res.redirect_uri = req.verify_redirect_uri!(@client.redirect_uri)
        @redirect_uri  = res.redirect_uri
        @response_type = req.response_type
        case req.response_type
          when :code
            authorization_code = current_account.authorization_codes.create(:client => @client, :redirect_uri => res.redirect_uri)
            res.code = authorization_code.token
          when :token
            # 现在未使用 refresh_token(optional), 如有需要可自行添加
            res.access_token = current_account.access_tokens.create(:client => @client).to_bearer_token
          else
            req.unsupported_response_type!
        end
        res.approve!

        # 如果设置是否同意授权选项, 拒绝授权时用下方代码
        # req.access_denied!
      end
      respond_oauth2 *authorization_endpoint.call(request.env)
    else
      flash.now[:error] = 'Invalid email or password'
      render 'oauth2/authorize'
    end
  end

  # 如果需要返回refresh_token, 请在获取access_token时添加相关参数
  # access_token.to_bear_token(:with_refresh_token)
  post :token, :provides => [:json] do
    token_endpoint = Rack::OAuth2::Server::Token.new do |req, res|
      client = Client.find_by(identifier: req.client_id) || req.invalid_client!
      client.secret == req.client_secret || req.invalid_client!
      case req.grant_type
        when :authorization_code
          code = AuthorizationCode.valid.find_by(token: req.code)
          req.invalid_grant! if code.blank? || code.redirect_uri != req.redirect_uri
          res.access_token = code.access_token.to_bearer_token
        when :password
          # password 认证类型用于直接登录并返回access_token
          # NOTE: 这里password是明文的
          account = Account.authenticate(req.username, req.password) || req.invalid_grant!
          current_access_token = account.access_tokens.valid.where(client_id: client.id).first
          access_token = current_access_token ? current_access_token.refresh_lifetime : account.access_tokens.create(:client => client)
          res.access_token = access_token.to_bearer_token
        when :client_credentials
          res.access_token = client.access_tokens.create.to_bearer_token
        when :refresh_token
          # 预留代码, 可正常运行, 用 refresh_token 更新 access_token
          refresh_token = client.refresh_tokens.valid.find_by(token: req.refresh_token)
          req.invalid_grant! unless refresh_token
          res.access_token = refresh_token.access_tokens.create.to_bearer_token
        else
          req.unsupported_grant_type!
      end
    end

    token_endpoint.call(request.env)
  end

  # 通过 access_token, 返回当前用户信息和access_token相关信息
  get :current_account, :provides => [:json] do
    api_rescue do
      access_token = AccessToken.valid.find_by_token(params[:access_token])
      return { status: 'fail', reason: [ t('api.errors.invalid_access_token') ] }.to_json unless access_token
      { status: 'succ', account: access_token.account.to_api, access_token: access_token.to_api }.to_json
    end
  end
end