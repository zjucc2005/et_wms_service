# encoding: utf-8
EtWmsService::App.controllers :"#{'api_v1.0_account_groups'}", :map => 'api/v1.0/account_groups' do

  before do
    load_api_request_params
  end

  post :create,:provides => [:json] do
    api_rescue do
      authenticate_access_token

      @ag=AccountGroup.new(account_group_params)
      @ret_data = @ag.save ?
        { status: 'succ', data: @ag.to_api } :
        { status: 'fail', reason: @ag.errors.full_messages }
      @ret_data.to_json
    end
  end


  #获取单个account group信息, 同时返回能否删除的标志
  get :show, :map => ':id/show', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @account_group = AccountGroup.find_by(id: params[:id])
      @ret_data = @account_group ?
        { status: 'succ', data: @account_group.to_api } :
        { status: 'fail', reason: [ t('api.errors.not_found', :model => 'Account group', :id => params[:id]) ] }
      @ret_data.to_json
    end
  end

  #修改名称, 和Account, Role两个表的多对多关联
  put :update, :map=> ':id/update', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @account_group = AccountGroup.find_by(id: params[:id])
      if @account_group
        @ret_data = @account_group.update(account_group_params) ?
          { status: 'succ', data: @account_group.to_api } :
          { status: 'fail', reason: @account_group.errors.full_messages }
        @ret_data.to_json
      else
        raise t('api.errors.not_found', :model => 'Account group', :id => params[:id])
      end
    end
  end

  #列表查询  get/index
  get :index , :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page      = params['page']     || @request_params['page']     || 1
      per_page  = params['per_page'] || @request_params['per_page'] || 10
      filters   = params['q']        || @request_params['q']        || {}

      query = AccountGroup.query_filter(filters)
      @count = query.count
      @account_groups = query.order(:created_at => :asc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @account_groups.map(&:to_api), page: page, per_page: per_page, count: @count }.to_json
    end
  end

  #删除
  delete :delete, :with => :id, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @account_group = AccountGroup.find_by(id: params[:id])
      if @account_group
        @ret_data = @account_group.can_delete? && @account_group.destroy ?
          { status: 'succ' } :
          { status: 'fail', reason: [ t('api.errors.cannot_delete', :model => 'Account group', :id => params[:id]) ] }
        @ret_data.to_json
      else
        raise t('api.errors.not_found', :model => 'Account group', :id => params[:id])
      end
    end
  end
end