# encoding: utf-8
EtWmsService::App.controllers :"#{'api_v1.0_accounts'}", :map => 'api/v1.0/accounts' do

  before do
    load_api_request_params
  end

  # 账号注册
  # { email: "", password: "", password_confirmation: "", nickname: "" }
  post :registration, :provides => [:json] do
    api_rescue do
      account = Account.find_by(email: params[:email])

      if account
        raise t('api.errors.account.email_taken', :email => params[:email])
      else
        confirmation_token = Account.new_token
        account = Account.new(
          email: params[:email],
          password: params[:password],
          password_confirmation: params[:password_confirmation],
          confirmation_digest: Account.digest(confirmation_token),
          nickname: params[:nickname],
          is_valid: false
        )
        if account.save
          { status: 'succ', data: { email: account.email, confirmation_token: confirmation_token } }.to_json
        else
          { status: 'fail', reason: account.errors.full_messages }.to_json
        end
      end
    end
  end


  # 账号激活
  # { email: "", confirmation_token: "" }
  get :confirm, :provides => [:json] do
    api_rescue do
      account = Account.find_by(email: params[:email])
      if account
        if account.authenticated?(:confirmation, params[:confirmation_token])
          account.update(confirmed_at: Time.now)
          { status: 'succ' }.to_json
        else
          raise t('api.errors.account.invalid_email_or_confirmation')
        end
      else
        raise t('api.errors.account.invalid_email_or_confirmation')
      end
    end
  end


  # ADMIN 创建用户
  # 参数 - :email, :nickname, :password, :password_confirmation, :role_ids, :channel_ids, :account_group_ids
  post :create, :provides => [ :json ] do
    api_rescue do
      authenticate_access_token
      @request_params = validates_roles_relation(@request_params)

      @new_account = Account.new(account_params_create)
      @new_account.confirmed_at = Time.now.utc
      @ret_data = @new_account.save ?
        { :status => 'succ', :data => @new_account.to_api } :
        { :status => 'fail', :reason => @new_account.errors.full_messages }

      @ret_data.to_json
    end
  end


  # ADMIN 创建用户(批量)
  post :batch_create, :provides => [ :json ] do
    api_rescue do
      authenticate_access_token
      validate_array('resource')

      data = Array.new

      ActiveRecord::Base.transaction do
        @request_params['resource'].each_with_index do |account_params, index|
          account_params = validates_roles_relation(account_params)

          new_account = Account.new(account_params)
          new_account.confirmed_at = Time.now.utc
          if new_account.validate
            new_account.save!
            data << new_account.to_api
          else
            raise t('api.errors.batch_create_error', :index => index)
          end
        end
      end

      { :status => 'succ', :data => data }.to_json
    end
  end


  # 验证创建用户参数
  post :validate, :provides => [ :json ] do
    api_rescue do
      authenticate_access_token
      @request_params = validates_roles_relation(@request_params)

      new_account = Account.new(account_params_create)
      @ret_data = new_account.validate ?
        { :status => 'succ' } :
        { :status => 'fail', :reason => new_account.errors.full_messages }
      @ret_data.to_json
    end
  end


  # 用户列表查询
  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page      = params['page']     || @request_params['page']     || 1
      per_page  = params['per_page'] || @request_params['per_page'] || 10
      filters   = params['q']        || @request_params['q']        || {}

      # 查询channel以及子channel下的用户
      filters['channels'] = {}
      filters['channels']['id_in']= @request_account.accessible_channels.pluck(:id) unless @request_account.super_admin?

      query     = Account.query_filter(filters).distinct
      @count    = query.count
      @accounts = query.order(:created_at => :asc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @accounts.map(&:to_api), page: page, per_page: per_page, count: @count }.to_json
    end
  end


  # 单个用户查询
  get :show, :map => ':id/show', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @account = Account.find_by(id: params[:id])
      @ret_data = @account ?
        { status: 'succ', data: @account.to_api } :
        { status: 'fail', reason: [ t('api.errors.not_found', :model => 'Account', :id => params[:id]) ] }
      @ret_data.to_json
    end
  end


  # 用户信息更新(主表信息, 关联表用户组, 角色)
  # 参数 - :nickname, :telephone, :account_group_ids, :role_ids, :channel_ids
  put :update, :map => ':id/update', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @account = Account.find_by(id: params[:id])
      if @account
        @ret_data = @account.update(account_params_update) ?
          { status: 'succ', data: @account.to_api } :
          { status: 'fail', reason: @account.errors.full_messages }
        @ret_data.to_json
      else
        raise t('api.errors.not_found', :model => 'Account', :id => params[:id])
      end
    end
  end

  # 用户密码更新(原密码, 新密码, 密码确认)
  # 参数 - :current_password, :password, :password_confirmation
  put :update_password, :map => ':id/update_password', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @account = Account.find_by(id: params[:id])
      if @account
        p = account_params_update_password
        if @account.has_password?(p['current_password'])
          @ret_data = @account.update(password: p['password'], password_confirmation: p['password_confirmation']) ?
            { status: 'succ' } :
            { status: 'fail', reason: @account.errors.full_messages }
          @ret_data.to_json
        else
          raise t('api.errors.password_wrong')
        end
      else
        raise t('api.errors.not_found', :model => 'Account', :id => params[:id])
      end
    end
  end

  # 用户删除
  # 参数 - :id
  # 返回 - { 'status' => 'succ/fail', 'reason' => Array(if failed) }
  delete :delete, :map=> ':id/delete', :provides=>[:json] do
    api_rescue do
      authenticate_access_token

      @account = Account.find_by(id: params[:id])
      raise t('api.errors.cannot_delete', :model => 'Account', :id => params[:id])  if @account == @request_account
      if @account
        @ret_data = @account.destroy ?
          { status: 'succ'} :
          { status: 'fail', reason: @account.errors.full_messages }
        @ret_data.to_json
      else
        raise t('api.errors.not_found', :model => 'Account', :id => params[:id])
      end
    end
  end

  get :mp4_id, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @accounts = Account.where(email: @request_params['emails'])
      data = @accounts.collect{|account| { email: account.email, mp4_id: account.mp4_id} }
      { status: 'succ', data: data }.to_json
    end
  end

end