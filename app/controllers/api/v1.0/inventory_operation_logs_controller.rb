# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_inventory_operation_logs', :map => 'api/v1.0/inventory_operation_logs' do

  before do
    load_api_request_params
  end

  # 2.8.1 库存操作日志列表(通用)
  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = InventoryOperationLog.query_filter(filters.merge(query_privilege))
      count = query.count
      @inventory_operation_logs = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @inventory_operation_logs.map(&:to_api), page: page, per_page: per_page, count: count }.to_json
    end
  end

  # 2.4.6 库存人工解冻操作
  post :inventory_unfreeze, :map => ':id/inventory_unfreeze', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inventory_operation_log

      @inventory_operation_log.inventory_unfreeze
      { status: 'succ' }.to_json
    end
  end

  # 2.8.3 上架(操作)日志(操作员)
  get :mount, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      query = InventoryOperationLog.where(operation: 'mount', operator_id: current_account.id, status: nil)
      count = query.count
      @inventory_operation_logs = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @inventory_operation_logs.map(&:to_api), page: page, per_page: per_page, count: count }.to_json
    end
  end

  # 2.8.4 上架(操作)日志回退
  post :mount_rollback, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      validate_presence('inventory_operation_log_id')
      log_id = @request_params['inventory_operation_log_id']
      log = InventoryOperationLog.where(id: log_id, operation: 'mount', operator_id: current_account.id, status: nil).first
      if log
        ActiveRecord::Base.transaction do
          log.update!(status: 'rollback')  # 日志回滚
          # 库存下架
          inventory               = log.inventory
          mount_inventory_info    = inventory.inventory_infos.where(batch_num: log.batch_num, shelf_num: log.shelf_num).first # 已上架库存
          unmount_inventory_info  = inventory.inventory_infos.where(batch_num: log.batch_num, shelf_num: nil).first           # 未上架库存
          prev_quantity           = unmount_inventory_info.quantity
          prev_available_quantity = unmount_inventory_info.available_quantity
          rollback_quantity       = mount_inventory_info.quantity
          unmount_inventory_info.update!(
            quantity:           prev_quantity           + rollback_quantity,
            available_quantity: prev_available_quantity + rollback_quantity
          )
          mount_inventory_info.destroy!

          # remote_inbound_batch_mount_rollback(log)  # >> CALL API - INBOUND 入库服务的操作, 待更新
        end
        { status: 'succ' }.to_json
      else
        raise t('api.errors.not_found', :model => 'InventoryOperationLog', :id => log_id)
      end
    end
  end

end