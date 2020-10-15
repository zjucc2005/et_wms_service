# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_outbound_orders', :map => 'api/v1.0/outbound_orders' do

  before do
    load_api_request_params
  end

  # 2.1.1 出库订单列表(查询)
  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = OutboundOrder.query_filter(filters.merge(query_privilege))
      count = query.count
      @outbound_orders = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @outbound_orders.map(&:to_api_simple), page: page, per_page: per_page, count: count }.to_json
    end
  end

  # 2.2.2 出库订单详情
  get :show, :map => ':id/show', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_order
      { status: 'succ', data: @outbound_order.to_api }.to_json
    end
  end

  # 2.2.3 出库订单分配操作员(单个) ADMIN
  post :allocate_operator, :map => ':id/allocate_operator', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_order
      validate_presence('operator')
      validate_string('operator')

      if @outbound_order.can_allocate_operator?
        account = Account.find_by_email(@request_params['operator'].strip)
        raise 'operator not found' if account.nil?
        @outbound_order.update(operator_id: account.id, operator: account.email, status: 'allocated') ?
          { status: 'succ' }.to_json :
          { status: 'fail', reason: @outbound_order.errors.full_messages }.to_json
      else
        raise t('api.errors.outbound_orders.cannot_allocate', :id => params[:id])
      end
    end
  end

  # 2.2.4 出库订单分配操作员(批量) ADMIN
  post :allocate_operators, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_presence('resource')
      validate_array('resource')

      ActiveRecord::Base.transaction do
        @request_params['resource'].each_with_index do |resource, index|
          begin
            raise t('api.errors.blank', :field => 'operator') if resource['operator'].blank?
            OutboundOrder.where(id: resource['ids']).each do |outbound_order|
              if outbound_order.can_allocate_operator?
                outbound_order.allocate_operator!(resource['operator'])
              else
                if outbound_order.outbound_method.blank?
                  raise t('api.errors.outbound_orders.outbound_method_blank')
                else
                  raise t('api.errors.outbound_orders.cannot_allocate', :id => outbound_order.id)
                end
              end
            end
          rescue Exception => e
            logger.info "outbound_orders allocate_operators failure: #{e.message}"
            raise "index[#{index}], error: #{e.message}"
          end
        end
      end

      { status: 'succ' }.to_json
    end
  end

  # 2.2.5 查询出库订单的取货信息 ADMIN
  get :picking_infos, :map => ':id/picking_infos', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_order

      unless @outbound_order.has_operate_infos?
        # remote_get_picking_infos(@outbound_order) # 待处理
        reload_outbound_order
      end
      { status: 'succ', data: @outbound_order.outbound_skus.map(&:to_api) }.to_json
    end
  end

  # 2.2.6 待取货出库订单列表(手持端) ADMIN
  get :wait_to_operate, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @outbound_orders = OutboundOrder.where(operator_id: current_account.id, status: 'allocated', has_operate_infos: true)
      { status: 'succ', data: @outbound_orders.map(&:to_api_simple) }.to_json
    end
  end

  # 2.2.7 出库订单操作(取货完毕) ADMIN
  post :picked, :map => ':id/picked', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_order

      if @outbound_order.can_pick?
        case @outbound_order.outbound_method
          # when 'picking' then remote_outbound_operation(@outbound_order)  # 待处理
          when 'seeding' then @outbound_order.update!(status: 'picked')
          else raise "invalid outbound method, [#{@outbound_order.outbound_method}]"
        end
      elsif @outbound_order.status == 'cancel'
        raise t('api.errors.outbound_orders.already_cancel', :batch_num => @outbound_order.batch_num)
      else
        raise t('api.errors.invalid_operation')
      end

      { status: 'succ' }.to_json
    end
  end

  # 2.2.8 出库订单修改 ADMIN
  put :update, :map => ':id/update', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_order
      validate_array('outbound_skus')

      if @outbound_order.can_cancel?
        ActiveRecord::Base.transaction do
          if @outbound_order.is_picked?
            # remote_create_reshelf_notification_for_order(@outbound_order) # 待处理
          elsif @outbound_order.has_operate_infos?
            # remote_remove_picking_infos(@outbound_order) # 待处理
          end
          @new_outbound_order = update_outbound_skus(@outbound_order, @request_params['outbound_skus'])
        end
      else
        raise t('api.errors.cannot_update', :model => 'InboundOrder', :id => params[:id])
      end
      { status: 'succ', data: @new_outbound_order.to_api }.to_json
    end
  end

  # 2.2.9 出库订单取消 ADMIN
  post :cancel, :map => ':id/cancel', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_outbound_order

      if @outbound_order.can_cancel?
        if @outbound_order.is_picked?
          # remote_create_reshelf_notification_for_order(@outbound_order) # 待处理
        elsif @outbound_order.has_operate_infos?
          # remote_remove_picking_infos(@outbound_order)  # 待处理
        end
        @outbound_order.cancel!
      else
        raise t('api.errors.cannot_cancel', :model => 'InboundOrder', :id => params[:id])
      end
      { status: 'succ' }.to_json
    end
  end

  # 2.2.10 出库订单选择分配方式 ADMIN
  post :allocate_method, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_array('ids')
      validate_presence('ids')
      validate_presence('outbound_method')
      raise 'invalid outbound method' unless %w[picking].include?(@request_params['outbound_method'])

      @outbound_orders = OutboundOrder.where(id: @request_params['ids']).query_filter(query_privilege)

      ActiveRecord::Base.transaction do
        begin
          @outbound_orders.each do |outbound_order|
            if outbound_order.can_allocate_method?
              outbound_order.allocate_method!(@request_params['outbound_method'])
            else
              raise t('api.errors.outbound_orders.cannot_allocate', :id => outbound_order.id)
            end
          end

          # create_wave(@request_params['ids']) if @request_params['outbound_method'] == 'seeding'
        rescue Exception => e
          logger.info "outbound_orders allocate_method failure: #{e.message}"
          raise e.message
        end
      end

      { status: 'succ' }.to_json
    end
  end

  # 2.2.11 出库订单取消(批量) ADMIN
  post :batch_cancel, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_array('ids')
      validate_presence('ids')

      @outbound_orders = OutboundOrder.where(id: @request_params['ids']).query_filter(query_privilege)
      # validate if all selected orders belongs to the same depot
      raise 'unable to cancel outbound_orders with different depot_code' if @outbound_orders.pluck(:depot_code).uniq.length > 1
      # validate if all selected orders can be cancelled
      @outbound_orders.each do |outbound_order|
        raise I18n.t('api.errors.cannot_cancel', :model => 'InboundOrder', :id => outbound_order.id) unless outbound_order.can_cancel?
      end

      @picked_ids = Array.new

      @outbound_orders.each do |outbound_order|
        if outbound_order.is_picked?
          # add to cached variable, and handle together
          @picked_ids << outbound_order.id
        elsif outbound_order.has_operate_infos?
          # remote_remove_picking_infos(outbound_order) # 待处理
          outbound_order.cancel!
        else
          outbound_order.cancel!
        end
      end

      # handle cached variable
      if @picked_ids.any?
        @picked_outbound_orders = OutboundOrder.where(id: @picked_ids)
        @picked_outbound_skus   = OutboundSku.where(outbound_order_id: @picked_ids).
          select('sku_code, barcode, sku_owner, SUM(quantity) AS quantity').
          group(:sku_code, :barcode, :sku_owner)
        refer_num     = "#{@picked_outbound_orders.first.batch_num}x#{@picked_outbound_orders.count}"
        depot_code    = @picked_outbound_orders.first.depot_code
        outbound_skus = @picked_outbound_skus.map(&:to_api_reshelf)

        ActiveRecord::Base.transaction do
          remote_create_reshelf_notification(refer_num, depot_code, outbound_skus)
          @picked_outbound_orders.each{|outbound_order| outbound_order.cancel! }
        end
      end

      { status: 'succ' }.to_json
    end
  end

  # 2.2.12 mypost4u包裹确认日志
  get :mypost4u_parcel_confirmation_logs, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = OutboundOrder.where(mp4_confirmed: true).query_filter(filters.merge(query_privilege))
      count = query.count
      @outbound_orders = query.order(:mp4_confirmed_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @outbound_orders.map(&:to_api_mp4_confirm_logs), page: page, per_page: per_page, count: count }.to_json
    end
  end

  # 2.2.13 已取货订单查询 picked
  get :picked_index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      filters  = params['q'] || @request_params['q'] || {}
      @outbound_orders = OutboundOrder.query_filter(filters.merge(query_privilege)).where(status: 'printed')
      { status: 'succ', data: @outbound_orders.map(&:to_api) }.to_json
    end
  end

  # 2.2.14 批量上传运单号
  post :batch_upload_shpmt_num, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_array('resource')

      OutboundOrder.batch_update_shpmt_num(@request_params['resource'])
      { status: 'succ' }.to_json
    end
  end

  # 2.2.15 出库订单详情(识别号查询)
  get :search, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_presence('num')

      @outbound_order = OutboundOrder.where('batch_num = :num OR shpmt_num = :num', { num: @request_params['num'].strip }).first
      if @outbound_order
        { status: 'succ', data: @outbound_order.to_api }.to_json
      else
        raise t('api.errors.not_found', :model => 'OutboundOrder', :id => nil)
      end
    end
  end

  # 2.2.16 出库订单提交退货
  post :return, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_presence('batch_num')
      validate_array('outbound_skus')

      # params filter
      outbound_skus = []
      @request_params['outbound_skus'].each do |ele|
        if ele['sku_code'].present?
          outbound_skus << { sku_code: ele['sku_code'], barcode: ele['barcode'], quantity: ele['quantity'], sku_owner: ele['sku_owner'] }
        end
      end

      outbound_order = OutboundOrder.where(batch_num: @request_params['batch_num']).first
      if outbound_order
        unless outbound_order.can_return?
          raise t('api.errors.cannot_return', :model => 'OutboundOrder', :id => outbound_order.id)
        end
        ActiveRecord::Base.transaction do
          outbound_order.update!(status: 'returned', returned_at: Time.now)
          outbound_order.returned_orders.create!(
            returned_skus: outbound_skus,
            operator:      current_account['email']
          )
          # remote_create_reshelf_notification(outbound_order.batch_num,
          #                                    outbound_order.depot_code,
          #                                    outbound_order.outbound_notification.channel,
          #                                    outbound_skus)
        end
        { status: 'succ' }.to_json
      else
        raise t('api.errors.not_found_batch_num', :model => 'OutboundOrder', :batch_num => @request_params['batch_num'])
      end
    end
  end

  # 2.2.17 退货订单列表
  get :returned_index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = OutboundOrder.query_filter(filters.merge(query_privilege)).where(status: 'returned')
      count = query.count
      @outbound_orders = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @outbound_orders.map(&:to_api_returned), page: page, per_page: per_page, count: count }.to_json
    end
  end


end