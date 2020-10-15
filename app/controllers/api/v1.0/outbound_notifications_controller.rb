# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_outbound_notifications', :map => 'api/v1.0/outbound_notifications' do

  before do
    load_api_request_params
  end

  # 2.1.1 创建出库预报 CLIENT
  post :create, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_array('outbound_orders')

      ActiveRecord::Base.transaction do
        @outbound_notification = OutboundNotification.create!(
          scheduled_time: @request_params['scheduled_time'],
          created_by: current_account.id,
          channel: current_channel)
        @request_params['outbound_orders'].each_with_index do |resource, index|
          begin
            validate_shpmt_product(resource['shpmt_product'].upcase)
            validate_shpmt_addr_info(resource['shpmt_addr_info'])
            resource['shpmt_addr_info']['sender']    = add_field_to(resource['shpmt_addr_info']['sender'], 'surname')
            resource['shpmt_addr_info']['recipient'] = add_field_to(resource['shpmt_addr_info']['recipient'], 'surname')
            validate_uniqueness_of_order_num(resource['order_num'])

            outbound_order = @outbound_notification.outbound_orders.create!(
              order_num:       resource['order_num'],
              depot_code:      resource['depot_code'],
              shpmt_num:       resource['shpmt_num'],
              shpmt_product:   resource['shpmt_product'].upcase,
              shpmt_addr_info: resource['shpmt_addr_info']
            )
            outbound_skus_construct(outbound_order, resource['outbound_skus'])
          rescue Exception => e
            logger.info "outbound_notification create failure: #{e.message}"
            raise "index[#{index}], error: #{e.message}"
          end
        end
      end

      { status: 'succ', data: @outbound_notification.to_api }.to_json
    end
  end

  # 2.1.2 出库预报列表(查询)
  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = OutboundNotification.query_filter(filters.merge(query_privilege))
      # query = query.where.not(created_by: 'system')  # 货主不显示由系统创建的出库预报
      count = query.count
      @outbound_notifications = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @outbound_notifications.map(&:to_api_simple), page: page, per_page: per_page, count: count }.to_json
    end
  end

  # 2.1.3 出库预报详情
  get :show, :map =>':id/show', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_notification
      { status: 'succ', data: @outbound_notification.to_api }.to_json
    end
  end

  # 2.1.4 出库预报选择分配方式 ADMIN
  post :allocate_method , :map =>':id/allocate_method' , :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_notification
      if @outbound_notification.can_allocate?
        ActiveRecord::Base.transaction do
          @outbound_notification.update!(allocator_id: current_account.id, allocator: current_account.email, status: 'in_process')
          @outbound_notification.update_method(@request_params['outbound_method'])
        end
      else
        raise t('api.errors.invalid_operation')
      end

      { status: 'succ'}.to_json
    end
  end

  # 2.1.5 出库预报完成 CLIENT
  post :finish , :map =>':id/finish' , :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_notification
      if @outbound_notification.can_finish?
        @outbound_notification.update!(status: 'finished')
      else
        raise t('api.errors.cannot_finish', :model => 'OutboundNotification', :id => params[:id])
      end
      { status: 'succ', data: @outbound_notification.to_api_simple }.to_json
    end
  end

  # 2.1.6 出库预报删除
  delete :delete , :map =>':id/delete' , :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_notification
      if @outbound_notification.can_delete?
        @outbound_notification.destroy!
        { status: 'succ'}.to_json
      else
        raise t('api.errors.cannot_delete', :model => 'OutboundNotification', :id => params[:id])
      end
    end
  end

  # 2.1.7 mypost4u 包裹确认 CLIENT
  post :mypost4u_parcels_confirm, :map => ':id/mypost4u_parcels_confirm', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_notification

      if @outbound_notification.mp4_confirmed?
        raise t('api.errors.invalid_operation')
      else
        parcel_nums = @outbound_notification.outbound_orders.wait_to_mp4_confirm.pluck(:parcel_num)
        # remote_mp4_parcels_confirm(parcel_nums)
      end

      { status: 'succ' }.to_json
    end
  end

  # 2.1.8 出库预报关闭 ADMIN
  post :close, :map => ':id/close', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_notification

      if @outbound_notification.can_close?
        @outbound_notification.update!(status: 'closed')
      else
        raise I18n.t('api.errors.outbound_notifications.cannot_operate', :id => params[:id])
      end
      { status: 'succ', data: @outbound_notification.to_api_simple }.to_json
    end
  end

  # 2.1.9 出库预报重新打开 ADMIN
  post :reopen, :map => ':id/reopen', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_notification

      if @outbound_notification.can_reopen?
        @outbound_notification.update!(status: 'reopened')
      else
        raise I18n.t('api.errors.outbound_notifications.cannot_operate', :id => params[:id])
      end
      { status: 'succ', data: @outbound_notification.to_api_simple }.to_json
    end
  end

end