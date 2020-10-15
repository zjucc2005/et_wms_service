# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_statistics', :map => 'api/v1.0/statistics' do

  before do
    load_api_request_params
  end

  # 2.9.1 库存数量统计
  get :inventories_count, :map => 'inventories/count', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      query = Inventory.query_filter(query_privilege)
      global_caution_threshold = InventorySetting.personal_settings(current_account.id)['global_caution_threshold']
      caution_count = query.where('(inventories.quantity < inventories.caution_threshold) OR (inventories.caution_threshold IS NULL AND inventories.quantity < ?)', global_caution_threshold).count
      { status: 'succ', caution_count: caution_count }.to_json
    end
  end

  # 2.9.2 库存盘点任务数量统计
  get :inventory_check_tasks_count, :map => 'inventory_check_tasks/count', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      query = InventoryTask.query_filter(query_privilege).check_tasks
      new_count = query.where(status: 'new').count
      { status: 'succ', new_count: new_count }.to_json
    end
  end

  # 2.9.3 绩效统计
  get :performance_ranking, :map => 'performance/ranking', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      # params settings
      begin
        end_time   = Time.parse(@request_params['end_time'])
        begin_time = Time.parse(@request_params['begin_time'])
      rescue
        end_time   = Time.now.beginning_of_day
        begin_time = end_time - 30.days
      end
      top = Integer(@request_params['top']) rescue 5
      raise I18n.t('api.errors.greater_than', :field => 'top', :value => 0) if top <= 0

      # main
      query = InventoryOperationLog.query_filter(query_privilege)

      mount_ranking = Array.new
      result = query.where(operation: 'mount').
        where('created_at BETWEEN ? AND ?', begin_time, end_time).
        select('COUNT(*) AS count, operator').group(:operator)
      result = result.sort_by{ |obj| obj.count }
      1.upto([top, result.length].min) do |i|
        mount_ranking << { rank: i, count: result[i-1].count, account: result[i-1].operator }
      end
      if result.length > 5
        mount_ranking << { rank: 6, count: result[5, result.length].sum(&:count), account: 'rest' }
      end

      unmount_ranking = Array.new
      result = query.where(operation: 'unmount').
        where('created_at BETWEEN ? AND ?', begin_time, end_time).
        select('COUNT(*) AS count, operator').group(:operator)
      result = result.sort_by{ |obj| obj.count }
      1.upto([top, result.length].min) do |i|
        unmount_ranking << { rank: i, count: result[i-1].count, account: result[i-1].operator }
      end
      if result.length > 5
        unmount_ranking << { rank: 6, count: result[5, result.length].sum(&:count), account: 'rest' }
      end

      {
        status: 'succ',
        begin_time: begin_time.strftime('%F %T'),
        end_time: end_time.strftime('%F %T'),
        top: top,
        mount_ranking: mount_ranking,
        unmount_ranking: unmount_ranking
      }.to_json
    end
  end

  # 2.4.1 入库预报数量统计
  get :inbound_notifications_count, :map => 'inbound_notifications/count',:provides => [:json] do
    api_rescue do
      authenticate_access_token

      query = InboundNotification.query_filter(query_privilege)
      in_process_count = query.where(status: %w[in_process reopened]).count  # 处理中的入库预报数量
      new_count = query.where(status: %w[new]).count                         # 未入库的入库预报数量
      { status: 'succ', in_process_count: in_process_count, new_count: new_count }.to_json
    end
  end
end