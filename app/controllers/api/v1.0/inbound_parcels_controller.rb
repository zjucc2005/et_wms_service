# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_inbound_parcels', :map => 'api/v1.0/inbound_parcels' do
  before do
    load_api_request_params
  end

  # 2.3.1 入库包裹列表(已收货) ADMIN
  get :received, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = InboundParcel.query_filter(filters.merge({ inbound_notification: query_privilege })).where(status: %w[received on_shelf sent])
      count = query.count
      @inbound_parcels = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @inbound_parcels.map(&:to_api), page: page, per_page: per_page, count: count }.to_json
    end
  end

  # 2.3.2 入库包裹登记 ADMIN
  post :register, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      inbound_parcel = InboundParcel.query_filter({ inbound_notification: query_privilege }).where(parcel_num: params['parcel_num'] || @request_params['parcel_num']).first
      raise 'parcel not notified' if inbound_parcel.nil?
      if inbound_parcel.status == 'notified'
        inbound_parcel.update!(status: 'received', operator_id: current_account.id, operator: current_account.email)
      else
        raise 'parcel has already been registered'
      end

      { status: 'succ' }.to_json
    end
  end

  # 2.3.3 入库包裹上架 ADMIN
  post :operate, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      parcel_num = params['parcel_num'] || @request_params['parcel_num']
      shelf_num  = params['shelf_num']  || @request_params['space_num']
      raise 'parcel_num and shelf_num required' unless parcel_num.present? && shelf_num.present?

      @inbound_parcel = InboundParcel.query_filter({ inbound_notification: query_privilege }).where(parcel_num: parcel_num).first
      raise 'parcel not found' if @inbound_parcel.nil?
      if %w[notified received].include?(@inbound_parcel.status)
        @inbound_parcel.update!(status: 'on_shelf', space_num: shelf_num)
      else
        raise 'invalid status'
      end

      { status: 'succ', data: @inbound_parcel.to_api }.to_json
    end
  end

end