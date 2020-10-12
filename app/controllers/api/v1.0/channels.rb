# encoding: utf-8
EtWmsService::App.controllers :"#{'api_v1.0_channels'}", :map => 'api/v1.0/channels' do

  before do
    load_api_request_params
  end

  # Channel 列表查询
  # 返回 - { 'status' => 'succ/fail', 'reasons' => Array(if failed), 'data' => Array(multi) }
  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page      = params['page']     || @request_params['page']     || 1
      per_page  = params['per_page'] || @request_params['per_page'] || 10
      filters   = params['q']        || @request_params['q']        || {}

      query    = Channel.query_filter(filters)
      @count   = query.count
      @channels = query.order(:created_at => :asc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @channels.map(&:to_api), page: page, per_page: per_page, count: @count }.to_json
    end
  end


  # Channel 单例查询
  # 参数 - :id
  # 返回 - { 'status' => 'succ/fail', 'reasons' => Array(if failed), 'data' => Hash(single) }
  get :show, :map=> ':id/show', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @channel = Channel.find_by(id: params[:id])
      @ret_data = @channel ?
        { status: 'succ', data: @channel.to_api } :
        { status: 'fail', reason: [ t('api.errors.not_found', :model => 'Channel', :id => params[:id]) ] }
      @ret_data.to_json
    end
  end


  # Channel 新建
  # 参数 - :name(required), :parent_id(optional)
  # 返回 - { 'status' => 'succ/fail', 'reasons' => Array(if failed), 'data' => Hash(single) }
  post :create, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @channel = Channel.new(channel_params)
      @ret_data = @channel.save ?
        { status: 'succ', data: @channel.to_api } :
        { status: 'fail', reason: @channel.errors.full_messages }
      @ret_data.to_json
    end
  end


  # Channel 更新
  # 参数 - :name(required), :parent_id(optional)
  # 返回 - { 'status' => 'succ/fail', 'reasons' => Array(if failed), 'data' => Hash(single) }
  put :update, :map=> ':id/update', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @channel = Channel.find_by(id: params[:id])
      if @channel
        @ret_data = @channel.update(channel_params) ?
          { status: 'succ', data: @channel.to_api } :
          { status: 'fail', reason: @channel.errors.full_messages }
        @ret_data.to_json
      else
        raise t('api.errors.not_found', :model => 'Channel', :id => params[:id])
      end
    end
  end


  # Channel 删除
  # 参数 - :id
  # 返回 - { 'status' => 'succ/fail', 'reasons' => Array(if failed) }
  delete :delete, :map=> ':id/delete', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @channel = Channel.find_by(id: params[:id])
      if @channel
        @ret_data = (@channel.can_delete? && @channel.destroy) ?
          { status: 'succ' } :
          { status: 'fail', reason: [ t('api.errors.cannot_delete', :model => 'Channel', :id => params[:id]) ] }
        @ret_data.to_json
      else
        raise t('api.errors.not_found', :model => 'Channel', :id => params[:id])
      end
    end
  end
end