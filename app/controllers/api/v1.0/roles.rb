# encoding: utf-8
EtWmsService::App.controllers :"#{'api_v1.0_roles'}", :map => 'api/v1.0/roles' do

  before do
    load_api_request_params
  end

  # Role 列表查询
  # 参数 - :page, :per_page, :filters={ 'application_id_eq' => 1, 'name_in' => ['admin', 'customer'] }
  # 返回 - { 'status' => 'succ/fail', 'reason' => Array(if failed), 'data' => Array(multi) }
  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page      = params['page']     || @request_params['page']     || 1
      per_page  = params['per_page'] || @request_params['per_page'] || 10
      filters   = params['q']        || @request_params['q']        || {}

      query    = Role.query_filter(filters)
      @count   = query.count
      @roles   = query.order(:created_at => :asc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @roles.map(&:to_api), page: page, per_page: per_page, count: @count }.to_json
    end
  end

  # Role 单例查询
  # 参数 - :id
  # 返回 - { 'status' => 'succ/fail', 'reason' => Array(if failed), 'data' => Hash(single) }
  get :show, :map => ':id/show', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @role = Role.find_by(id: params[:id])
      @ret_data = @role ?
        { status: 'succ', data: @role.to_api } :
        { status: 'fail', reason: [ t('api.errors.not_found', :model => 'Role', :id => params[:id]) ] }
      @ret_data.to_json
    end
  end


end