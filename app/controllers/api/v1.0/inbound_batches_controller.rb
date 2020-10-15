# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_inbound_batches', :map => 'api/v1.0/inbound_batches' do

  before do
    load_api_request_params
  end

  # 2.2.1 入库批次列表
  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = InboundBatch.query_filter(filters.merge({ inbound_notification: query_privilege }))
      count = query.count
      @inbound_batches = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @inbound_batches.map(&:to_api_simple), page: page, per_page: per_page, count: count }.to_json
    end
  end

  # 2.2.2 入库批次详情
  get :show, :map => ':id/show', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_batch

      { status: 'succ', data: @inbound_batch.to_api }.to_json
    end
  end

  # 2.2.3 入库批次分配(操作员) ADMIN
  post :allocate, :map => ':id/allocate', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_batch
      validate_array('operator_ids')

      @inbound_batch.update(operator_ids: @request_params['operator_ids']) ?
        { status: 'succ', data: @inbound_batch.to_api }.to_json :
        { status: 'fail', reason: @inbound_batch.errors.full_messages }.to_json
    end
  end

  # 2.2.4 入库批次删除 ADMIN
  delete :delete, :map => ':id/delete', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_batch

      if @inbound_batch.can_delete?
          # remote_inventory_unregister(@inbound_batch)  # >> CALL API # 待处理
          @inbound_batch.destroy!
          { status: 'succ' }.to_json
      else
        raise t('api.errors.cannot_delete', :model => 'InboundBatch', :id => params[:id])
      end
    end
  end

  # 2.2.5 等待上架的入库批次 ADMIN
  get :wait_to_operate, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      @inbound_batches = InboundBatch.query_filter(operator_ids_cont: current_account.id, inbound_batch_skus: { problem_type: nil} ).
        where(status: %w[new in_process]).distinct

      { status: 'succ', data: @inbound_batches.map(&:to_api_operate) }.to_json
    end
  end

  # 2.2.6 入库批次操作(sku上架) ADMIN
  post :operate, :map => ':id/operate', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_batch
      load_inbound_batches_operate_params

      inbound_batch_sku = @inbound_batch.inbound_batch_skus.query_filter(inbound_sku: { barcode: @barcode }).where(problem_type: nil).first
      raise I18n.t('api.errors.inbound_batch.barcode_not_found', :barcode => @barcode) if inbound_batch_sku.nil?

      raise I18n.t('api.errors.greater_than', :field => 'Quantity', :value => 0) if @quantity <= 0
      raise I18n.t('api.errors.less_than_or_equal_to', :field => 'Quantity', :value => inbound_batch_sku.available_quantity) if @quantity > inbound_batch_sku.available_quantity

      # >> 上架, 调用库存API
      ActiveRecord::Base.transaction do
        operate_info = { shelf_num: @shelf_num, quantity: @quantity, operator_id: current_account.id, operator: current_account.email }
        inbound_batch_sku.operate_infos ||= []
        inbound_batch_sku.operate_infos << operate_info
        inbound_batch_sku.save!
        inbound_batch_sku.update_status!

        inventory_mount_params = {
          batch_num:  @inbound_batch.batch_num,
          sku_code:   inbound_batch_sku.inbound_sku.sku_code,
          barcode:    inbound_batch_sku.inbound_sku.barcode,
          # sku_owner:  inbound_batch_sku.inbound_sku.sku_owner,
          quantity:   @quantity,
          shelf_num:  @shelf_num,
          depot_code: @inbound_batch.inbound_notification.inbound_depot_code
        }

        @inbound_batch.update_status!
        # remote_inventory_mount(inventory_mount_params)  # >> CALL API  # 待处理
      end

      { status: 'succ' }.to_json
    end
  end

  # 2.2.7 入库批次操作(问题sku登记) ADMIN
  post :register_problem, :map => ':id/register_problem', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_batch
      load_inbound_batches_register_problem_params

      inbound_batch_sku = @inbound_batch.inbound_batch_skus.query_filter(inbound_sku: { barcode: @barcode }).where(problem_type: nil).first
      raise I18n.t('api.errors.inbound_batch.barcode_not_found', :barcode => @barcode) if inbound_batch_sku.nil?

      raise I18n.t('api.errors.greater_than', :field => 'Quantity', :value => 0) if @quantity <= 0
      raise I18n.t('api.errors.less_than_or_equal_to', :field => 'Quantity', :value => inbound_batch_sku.available_quantity) if @quantity > inbound_batch_sku.available_quantity

      ActiveRecord::Base.transaction do
        @inbound_batch.inbound_batch_skus.create!(
          inbound_sku_id:    inbound_batch_sku.inbound_sku_id,
          status:            inbound_batch_sku.status,
          quantity:          @quantity,
          problem_type:      @problem_type,
          problem_memo:      @problem_memo,
          production_date:   @production_date   || inbound_batch_sku.production_date,
          expiry_date:       @expiry_date       || inbound_batch_sku.expiry_date,
          country_of_origin: @country_of_origin || inbound_batch_sku.country_of_origin,
          abc_category:      @abc_category      || inbound_batch_sku.abc_category
        )
        if @quantity == inbound_batch_sku.quantity
          inbound_batch_sku.destroy!
        else
          inbound_batch_sku.update!(quantity: inbound_batch_sku.quantity - @quantity)
        end
        if @inbound_batch.inbound_batch_skus.normal.count == 0
          @inbound_batch.update!(status: 'finished')
        else
          @inbound_batch.update!(status: 'in_process')
        end

        inventory_register_decrease_params = {
          batch_num: @inbound_batch.batch_num,
          sku_code:  inbound_batch_sku.inbound_sku.sku_code,
          barcode:   inbound_batch_sku.inbound_sku.barcode,
          sku_owner: inbound_batch_sku.inbound_sku.sku_owner,
          quantity:  @quantity,
          memo:      @problem_type
        }
        # remote_inventory_register_decrease(inventory_register_decrease_params)  # >> CALL API # 待处理
      end

      { status: 'succ' }.to_json
    end
  end

  # 2.2.8 入库批次完成(问题批次)
  post :finish_problem, :map => ':id/finish_problem', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_batch

      if @inbound_batch.inbound_batch_skus.normal.count == 0
        @inbound_batch.update(status: 'finished')
      else
        raise t('api.errors.not_authorized')
      end
      { status: 'succ' }.to_json
    end
  end

  # >>> 上架操作回退, 待删除
  # post :mount_rollback, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #
  #     inbound_batch = InboundBatch.where(batch_num: @request_params['batch_num']).first
  #     raise 'inbound batch not found' if inbound_batch.nil?
  #     inbound_sku = inbound_batch.inbound_notification.inbound_skus.where(sku_code: @request_params['sku_code'], barcode: @request_params['barcode'], sku_owner: @request_params['sku_owner']).first
  #     raise 'inbound sku not found' if inbound_sku.nil?
  #     inbound_batch_sku = inbound_batch.inbound_batch_skus.where(inbound_sku_id: inbound_sku.id).first
  #     rollback_operate_infos = inbound_batch_sku.operate_infos.select do |info|
  #       info['operator']  == @request_params['operator'] &&
  #       info['quantity']  == @request_params['quantity'] &&
  #       info['shelf_num'] == @request_params['shelf_num']
  #     end
  #     if rollback_operate_infos.present?
  #       ActiveRecord::Base.transaction do
  #         inbound_batch_sku.operate_infos -= rollback_operate_infos
  #         inbound_batch_sku.save!
  #         inbound_batch_sku.update_status!
  #         inbound_batch.update_status!
  #       end
  #       { status: 'succ' }.to_json
  #     else
  #       raise 'inbound_batch_sku.operate_info not found'
  #     end
  #   end
  #
  # end
end