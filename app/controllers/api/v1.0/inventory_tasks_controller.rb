# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_inventory_tasks', :map => 'api/v1.0/inventory_tasks' do

  before do
    load_api_request_params
  end

  # === 后端专用 ===

  # 库存任务查询
  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = InventoryTask.query_filter(filters.merge(query_privilege))
      count = query.count
      @inventory_tasks = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @inventory_tasks.map(&:to_api_simple), page: page, per_page: per_page, count: count }.to_json
    end
  end

  # 库存任务详情查询
  get :show, :map => ':id/show', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inventory_task

      { status: 'succ', data: @inventory_task.to_api }.to_json
    end
  end

  # 创建库存转移任务
  post :create_transfer, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_create_transfer_task_params

      ActiveRecord::Base.transaction do
        @inventory_task = current_account.inventory_tasks.transfer_tasks.create!(
          channel: current_channel, scheduled_time: @request_params['scheduled_time'])
        @request_params['transfer_infos'].each_with_index do |resource, index|
          begin
            inventory = Inventory.find_by(id: resource['inventory_id'])
            inventory.create_transfer_task!(resource['transfer_quantity'], @inventory_task.id, @request_params['to_depot_code'])
          rescue
            raise t('api.errors.batch_create_error', :index => index)
          end
        end

        # remote_create_transfer_notification(@inventory_task) unless test_mode  # spec, 待处理
        @inventory_task.create_transfer_notification  # 待验证
      end

      { status: 'succ', data: @inventory_task.to_api }.to_json
    end
  end

  # 完成库存转移任务
  post :finish_transfer, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @inventory_task = InventoryTask.transfer_tasks.where(task_num: @request_params['task_num']).first
      raise "task_num #{@request_params['task_num']} not found" if @inventory_task.nil?
      raise t('api.errors.cannot_update', :model => 'InventoryTask', :id => @inventory_task.id) unless @inventory_task.can_update?

      @inventory_task.execute_inventory_task
      { status: 'succ' }.to_json
    end
  end

  # 取消库存转移任务
  post :cancel_transfer, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      @inventory_task = InventoryTask.transfer_tasks.where(task_num: @request_params['task_num']).first
      raise "task_num #{@request_params['task_num']} not found" if @inventory_task.nil?
      raise t('api.errors.cannot_update', :model => 'InventoryTask', :id => @inventory_task.id) unless @inventory_task.can_update?

      @inventory_task.cancel_inventory_task
      { status: 'succ' }.to_json
    end
  end

  # 创建库存盘点任务
  post :create_check, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      ActiveRecord::Base.transaction do
          begin
            @inventory_task = InventoryTask.get_check_task_type(current_account.id, current_channel, @request_params)
            raise t('api.errors.check_task_error') if @inventory_task.nil?
          rescue
            raise t('api.errors.check_task_error')
          end
      end
      { status: 'succ', data: @inventory_task.to_api }.to_json
    end
  end

  # 更新库存盘点任务
  post :update_check , :map => ':id/update_check', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inventory_task
      raise t('api.errors.cannot_update', :model => 'InventoryTask', :id => params[:id]) unless @inventory_task.can_update?

      ActiveRecord::Base.transaction do
        resource = @request_params['check_info']
        inventory = Inventory.where(barcode: resource['barcode']).first
        raise t('api.errors.inventory.not_found') if inventory.nil?
        check_info = @inventory_task.check_infos.find_by(inventory_id: inventory.id, shelf_num: resource['shelf_num'])
        check_info = inventory.create_check_task!(resource['shelf_num'], @inventory_task.id) if check_info.nil?
        check_info.update!(check_quantity: resource['check_quantity'], operator_id: current_account.id, operator: current_account.email)
      end
      { status: 'succ', data: @inventory_task.to_api }.to_json
    end
  end

  # 确认库存盘点任务
  post :finish_check , :map => ':id/finish_check', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inventory_task

      if @inventory_task.status == 'pending'
        @inventory_task.execute_inventory_task
        { status: 'succ', data: @inventory_task.to_api }.to_json
      else
        raise t('api.errors.cannot_finish', :model => 'InventoryTask', :id => params[:id])
      end
    end
  end

  post :cancel, :map => ':id/cancel', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inventory_task

      @inventory_task.can_cancel? and @inventory_task.operation != 'transfer' ?
        @inventory_task.cancel_inventory_task :
        raise(t('api.errors.cannot_cancel', :model => 'InventoryTask', :id => params[:id]))
      { status: 'succ' }.to_json
    end
  end


end