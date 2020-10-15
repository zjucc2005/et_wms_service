# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_inventories', :map => 'api/v1.0/inventories' do

  before do
    load_api_request_params
  end

  # 2.4.1 库存列表
  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = Inventory.query_filter(filters.merge(query_privilege))
      count = query.count
      @inventories = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @inventories.map(&:to_api_with_statistics), page: page, per_page: per_page, count: count }.to_json
    end
  end

  # 2.4.2 库存批次查询
  get :inventory_infos, :map => ':id/inventory_infos', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inventory

      @inventory_infos = @inventory.inventory_infos.remain
      { status: 'succ', data: @inventory_infos.map(&:to_api) }.to_json
    end
  end

  # 2.4.3 上月出库数量查询
  get :outbound_last_month, :map => ':id/outbound_last_month', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inventory

      { status: 'succ', data: @inventory.outbound_last_month }.to_json
    end
  end

  # 2.4.4 获取待解冻日志列表
  get :wait_to_unfreeze_logs, :map => ':id/wait_to_unfreeze_logs', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inventory

      { status: 'succ', data: @inventory.wait_to_unfreeze_logs.map(&:to_api) }.to_json
    end
  end

  # 2.4.5 库存人工冻结操作
  post :inventory_freeze, :map=> ':id/inventory_freeze', :provides=>[:json] do
    api_rescue do
      authenticate_access_token
      load_inventory

      freeze_quantity = @request_params['freeze_quantity'].to_i
      batch_num       = @request_params['batch_num']
      shelf_num       = @request_params['shelf_num']
      freeze_reason   = @request_params['freeze_reason']
      @inventory.inventory_freeze(freeze_quantity, batch_num, shelf_num, freeze_reason, current_account.id)
      if @inventory.validate
        { status: 'succ' , data: @inventory.wait_to_unfreeze_logs.map(&:to_api) }.to_json
      else
        { status: 'fail', reason: @inventory.errors.full_messages }.to_json
      end
    end
  end

  # 2.4.7 库存简易信息(右上)
  get :show_top_right, :map => ':id/show_top_right', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inventory

      { status: 'succ', data: @inventory.to_api_show_top_right }.to_json
    end
  end

  # 2.4.8 获取SKU当前货架号
  get :current_shelf_num, :map => 'current_shelf_num', :provides => [:json] do
    api_rescue do
      # authenticate_access_token
      validate_presence('sku_code')
      validate_presence('barcode')
      validate_presence('sku_owner')

      inventory = Inventory.joins(:account).where(
        'inventories.sku_code' => @request_params['sku_code'],
        'inventories.barcode' => @request_params['barcode'],
        'accounts.email' => @request_params['sku_owner']
      ).first
      raise 'inventory not found' if inventory.nil?
      @shelf_nums = inventory.inventory_infos.remain.where.not(shelf_num: nil).pluck(:shelf_num).uniq
      { status: 'succ', data: @shelf_nums }.to_json
    end
  end

  # 2.6.4 设置余量预警阈值(个别)
  put :update_caution_threshold, :map => ':id/update_caution_threshold', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inventory

      @inventory.update(inventory_caution_threshold) ?
        { status: 'succ', data: @inventory.to_api }.to_json :
        { status: 'fail', reason: @inventory.errors.full_messages }.to_json
    end
  end

  # 2.8.2 单个库存的操作日志(简易)
  get :operation_logs, :map => ':id/operation_logs', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inventory

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = @inventory.operation_logs.query_filter(filters).
        where(operation: %w[register register_decrease unmount transfer check])

      count = query.length
      @inventory_operation_logs = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @inventory_operation_logs.map(&:to_api_simple), page: page, per_page: per_page, count: count }.to_json
    end
  end

  # === 库存操作, 后端专用 (待删除) ===
  # # 2.7.1 库存增加(入库登记)
  # post :register_operation, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #
  #     Inventory::Operation.register_operation(@request_params, current_account['email'])
  #     { status: 'succ' }.to_json
  #   end
  # end
  #
  # # 2.7.8 库存减少(问题sku登记)
  # post :register_decrease_operation, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #
  #     Inventory::Operation.register_decrease_operation(@request_params, current_account['email'])
  #     { status: 'succ' }.to_json
  #   end
  # end
  #
  # # 2.7.2 库存减少(入库登记取消)
  # post :unregister_operation, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #
  #     Inventory::Operation.unregister_operation(@request_params, current_account['email'])
  #     { status: 'succ' }.to_json
  #   end
  # end
  #
  # # 2.7.3 库存调整(库存上架)
  # post :mount_operation, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #
  #     Inventory::Operation.mount_operation(@request_params, current_account['email'])
  #     { status: 'succ' }.to_json
  #   end
  # end
  #
  # # 2.7.4 库存减少(取货下架)
  # post :outbound_operation, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #
  #     Inventory::Operation.outbound_operation(@request_params, current_account['email'])
  #     { status: 'succ' }.to_json
  #   end
  # end
  #
  # # 2.7.5 生成待取货信息 && 冻结对应部分库存
  # post :get_picking_infos, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #
  #     @result = Inventory::Operation.get_picking_infos(@request_params, current_account['email'])
  #     { status: 'succ', data: @result }.to_json
  #   end
  # end
  #
  # # 2.7.6 取消待取货信息 & 解冻对应部分库存
  # post :remove_picking_infos, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #
  #     Inventory::Operation.remove_picking_infos(@request_params, current_account['email'])
  #     { status: 'succ' }.to_json
  #   end
  # end
  #
  # # 2.7.7 库存信息查询(单个) 可删除
  # get :search, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #
  #     @inventory = Inventory.where(sku_code: @request_params['sku_code'], barcode: @request_params['barcode'],
  #                                  sku_owner: @request_params['sku_owner']).first
  #     if @inventory
  #       { status: 'succ', data: @inventory.to_api }.to_json
  #     else
  #       raise 'Inventory not found'
  #     end
  #   end
  # end
  #
  # # 2.7.9 库存调整(数量批改)
  # post :modify_operation, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #
  #     Inventory::Operation.modify_operation(@request_params, current_account['email'])
  #     { status: 'succ' }.to_json
  #   end
  # end

end