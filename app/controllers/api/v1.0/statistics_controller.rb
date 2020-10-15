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

  # 2.4.1 出库订单数量统计
  get :outbound_orders_count, :map => 'outbound_orders/count', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      query = OutboundOrder.query_filter(query_privilege)
      new_count = query.where(status: %w[new]).count                      # 未处理的订单数量
      in_process_count = query.where(status: %w[allocated picked]).count  # 处理中的订单数量
      wait_to_mp4_confirm_count = query.wait_to_mp4_confirm.count         # 待确认的订单数量
      {
        status: 'succ',
        new_count: new_count,
        in_process_count: in_process_count,
        wait_to_mp4_confirm_count: wait_to_mp4_confirm_count,
      }.to_json
    end
  end

  # 2.4.2 出库订单趋势统计
  get :outbound_orders_trend, :map => 'outbound_orders/trend', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      query = OutboundOrder.query_filter(query_privilege).where(status: 'printed')
      days  = 30
      begin_day = Time.now.beginning_of_day - days.days

      # 趋势统计
      trend = Array.new
      days.times do |i|
        trend << query.where('sent_at BETWEEN ? AND ?', begin_day + i.days, begin_day + (i+1).days).count
      end

      # 排名统计
      ranking = Array.new
      result = query.where('sent_at BETWEEN ? AND ?', begin_day, begin_day + days.days).
        select('COUNT(*) AS count, created_by AS account').group(:created_by)
      result = result.sort_by{ |obj| obj.count }
      1.upto([5, result.length].min) do |i|
        ranking << { rank: i, count: result[i-1].count, account: result[i-1].account }
      end
      if result.length > 5
        ranking << { rank: 6, count: result[5, result.length].sum(&:count), account: 'rest' }
      end

      { status: 'succ', trend: trend, ranking: ranking }.to_json
    end
  end

  # 2.4.3 出库包裹统计, 最近 12 周
  get :outbound_orders_count_by_week, :map => 'outbound_orders/count_by_week', :provides => [:json] do
    api_rescue do
      authenticate_access_token

      default_weeks = 8
      weeks = @request_params['weeks'].to_i || default_weeks
      weeks = default_weeks if weeks > 12 || weeks <= 0
      query = OutboundOrder.where(status: %w[allocated picked printed sent])

      beginning_of_week = Time.now.beginning_of_week

      @data = []
      weeks.times do |i|
        begin_date = beginning_of_week - i.weeks
        end_date   = begin_date + 1.week

        _from_ = begin_date.strftime('%m.%d')
        if i == 0
          _to_ = nil
        else
          _to_ = (end_date - 1.day).strftime('%m.%d')
        end
        value = query.where('created_at BETWEEN ? AND ?', begin_date, end_date).count
        @data << { from: _from_, to: _to_, value: value }
      end

      { status: 'succ', data: @data }.to_json
    end
  end
end