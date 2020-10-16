# encoding: utf-8
EtWmsService::App.controllers :'api_v1.0_inbound_notifications', :map => 'api/v1.0/inbound_notifications' do

  before do
    load_api_request_params
  end

  # 2.1.1 创建入库预报 CLIENT
  post :create, :provides => [:json] do
    api_rescue do
      authenticate_access_token
      validate_inbound_notifications_create_params

      ActiveRecord::Base.transaction do
        @inbound_notification = InboundNotification.general_notifications.new(inbound_notification_params_create)
        @inbound_notification.created_by = current_account.id
        @inbound_notification.channel    = current_channel
        @inbound_notification.save!

        @request_params['inbound_skus'].each_with_index do |resource, index|
          begin
            # inbound_sku = @inbound_notification.inbound_skus.new(resource)
            # inbound_sku.validate_existence_of_sku_code unless test_mode  # spec
            inbound_sku = @inbound_notification.inbound_skus.construct_by_resource(resource)
            inbound_sku.save!
          rescue Exception => e
            logger.info "inbound_notification create failure: #{e.message}"
            raise "index[#{index}], error: #{e.message}"
          end
        end
      end

      { status: 'succ', data: @inbound_notification.to_api }.to_json
    end
  end

  # 库存管理服务创建转移任务时远程创建 ADMIN
  # post :create_transfer, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #     validate_inbound_notifications_create_transfer_params
  #
  #     ActiveRecord::Base.transaction do
  #       @inbound_notification = InboundNotification.transfer_notifications.new(inbound_notification_params_create)
  #       @inbound_notification.inbound_num = @request_params['task_num']
  #       @inbound_notification.created_by  = current_account.id
  #       @inbound_notification.channel     = current_channel
  #       @inbound_notification.data_source = 'system'
  #       @inbound_notification.save!
  #
  #       @request_params['inbound_skus'].each_with_index do |resource, index|
  #         begin
  #           inbound_sku = @inbound_notification.inbound_skus.new(resource)
  #           # inbound_sku.validate_existence_of_sku_code unless test_mode  # spec
  #           inbound_sku.save!
  #         rescue Exception => e
  #           logger.info "inbound_notification create failure: #{e.message}"
  #           raise "index[#{index}], error: #{e.message}"
  #         end
  #       end
  #     end
  #
  #     { status: 'succ', data: @inbound_notification.to_api }.to_json
  #   end
  # end

  # 2.1.2 入库预报列表
  get :index, :provides => [:json] do
    api_rescue do
      authenticate_access_token

      page     = params['page']     || @request_params['page']     || 1
      per_page = params['per_page'] || @request_params['per_page'] || 10
      filters  = params['q']        || @request_params['q']        || {}

      query = InboundNotification.query_filter(filters.merge(query_privilege))
      # query = query.where.not(created_by: 'system') unless has_backend_privilege  # 货主不显示由系统创建的入库预报

      count = query.count
      @inbound_notifications = query.order(:created_at => :desc).paginate(:page => page, :per_page => per_page)
      { status: 'succ', data: @inbound_notifications.map(&:to_api_simple), page: page, per_page: per_page, count: count }.to_json
    end
  end

  # 2.1.3 入库预报详情
  get :show, :map =>':id/show', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_notification
      { status: 'succ', data: @inbound_notification.to_api }.to_json
    end
  end

  # 2.1.4 入库预报收货
  post :receive, :map => ':id/receive', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_notification
      validate_array('inbound_received_skus')
      raise t('api.errors.inbound_notification.inbound_type_error', :id => params[:id]) unless @inbound_notification.valid_inbound_type?
      raise t('api.errors.inbound_notification.cannot_operate', :id => params[:id]) unless @inbound_notification.can_operate?

      ActiveRecord::Base.transaction do
        @inbound_received_info = @inbound_notification.inbound_received_infos.create!(
          receiver_id: current_account.id, receiver: current_account.email)
        @request_params['inbound_received_skus'].each_with_index do |resource, index|
          begin
            @inbound_received_info.create_inbound_received_skus!(resource)
          rescue Exception => e
            logger.info "inbound_notification receive failure: #{e.message}"
            raise "index[#{index}], error: #{e.message}"
          end
        end
        @inbound_notification.update!(status: 'in_process') if @inbound_notification.status == 'new'
      end

      { status: 'succ', data: @inbound_received_info.to_api }.to_json
    end
  end

  # 2.1.5 入库预报批次登记
  post :register, :map => ':id/register', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_notification
      validate_array('inbound_batch_skus')
      raise t('api.errors.inbound_notification.inbound_type_error', :id => params[:id]) unless @inbound_notification.valid_inbound_type?
      raise t('api.errors.inbound_notification.cannot_operate', :id => params[:id]) unless @inbound_notification.can_operate?

      ActiveRecord::Base.transaction do
        @inbound_batch = @inbound_notification.inbound_batches.create!(
          registrar_id: current_account.id, registrar: current_account.email
        )
        @request_params['inbound_batch_skus'].each_with_index do |resource, index|
          begin
            @inbound_batch.create_inbound_batch_skus!(resource)
            @inbound_batch.inbound_batch_skus.each do |sku|
              sku.get_current_shelf
            end
          rescue Exception => e
            logger.info "inbound_notification register failure: #{e.message}"
            raise "index[#{index}], error: #{e.message}"
          end
        end
        @inbound_batch.inventory_register  # 待验证
      end

      { status: 'succ', data: @inbound_batch.to_api }.to_json
    end
  end

  # 2.1.7 入库预报完成(货主)
  post :finish, :map => ':id/finish', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_notification

      raise t('api.errors.inbound_notification.inbound_type_error', :id => params[:id]) unless @inbound_notification.valid_inbound_type?
      if @inbound_notification.can_finish?
        ActiveRecord::Base.transaction do
          @inbound_notification.finish!
        end
      else
        raise t('api.errors.cannot_finish', :model => 'InboundNotification', :id => params[:id])
      end
      { status: 'succ', data: @inbound_notification.to_api }.to_json
    end
  end

  # 2.1.8 入库预报收货信息
  get :inbound_received_infos , :map => ':id/inbound_received_infos', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_notification

      { status: 'succ', data: @inbound_notification.inbound_received_infos.map(&:to_api) }.to_json
    end
  end

  # 2.1.9 入库预报批次登记信息
  get :inbound_batches , :map => ':id/inbound_batches', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_notification

      { status: 'succ', data: @inbound_notification.inbound_batches.map(&:to_api_simple) }.to_json
    end
  end

  # 2.1.10 入库预报删除 ADMIN & CLIENT
  delete :delete, :map => ':id/delete', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_notification

      if @inbound_notification.can_delete?
        ActiveRecord::Base.transaction do
          @inbound_notification.cancel_transfer_task if @inbound_notification.inbound_type == 'transfer'  # 待验证
          @inbound_notification.destroy
        end

        { status: 'succ' }.to_json
      else
        raise t('api.errors.cannot_delete', :model => 'InboundNotification', :id => params[:id])
      end
    end
  end

  # 2.1.11 入库预报sku增加  # CLIENT & ADMIN
  post :create_inbound_sku, :map => ':id/create_inbound_sku', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_notification

      raise t('api.errors.inbound_notification.inbound_type_error', :id => params[:id]) unless @inbound_notification.valid_inbound_type?
      raise t('api.errors.inbound_notification.cannot_operate', :id => params[:id]) unless @inbound_notification.can_operate?

      # @inbound_sku = @inbound_notification.inbound_skus.new(inbound_sku_params_create)
      # @inbound_sku.validate_existence_of_sku_code unless test_mode  # spec
      @inbound_sku = @inbound_notification.inbound_skus.construct_by_resource(inbound_sku_params_create)

      @inbound_sku.save ?
        { status: 'succ', data: @inbound_sku.to_api }.to_json :
        { status: 'fail', reason: @inbound_sku.errors.full_messages }.to_json
    end
  end

  # 2.1.14 取消出库订单并生成入库预报重新上架(出库服务调用), 待删除
  # post :create_reshelf, :provides => [:json] do
  #   api_rescue do
  #     authenticate_access_token
  #     validate_inbound_notifications_create_params
  #     validate_presence('refer_num')
  #     validate_presence('channel')
  #
  #     ActiveRecord::Base.transaction do
  #       # create InboundNotification
  #       @inbound_notification = InboundNotification.reshelf_notifications.new(inbound_notification_params_create)
  #       @inbound_notification.created_by = 'system'
  #       @inbound_notification.channel = @request_params['channel']
  #       @inbound_notification.save!
  #
  #       @request_params['inbound_skus'].each_with_index do |resource, index|
  #         begin
  #           inbound_sku = @inbound_notification.inbound_skus.new(
  #             sku_code:  resource['sku_code'],
  #             barcode:   resource['barcode'],
  #             sku_owner: resource['sku_owner'],
  #             quantity:  resource['quantity']
  #           )
  #           inbound_sku.validate_existence_of_sku_code unless test_mode  # spec
  #           inbound_sku.save!
  #         rescue Exception => e
  #           logger.info "inbound_notification create failure: #{e.message}"
  #           raise "index[#{index}], error: #{e.message}"
  #         end
  #       end
  #
  #       # create InboundReceivedInfo && InboundBatch
  #       @inbound_received_info = @inbound_notification.inbound_received_infos.create!(created_by: 'system')
  #       @inbound_batch         = @inbound_notification.inbound_batches.create!(refer_num: @request_params['refer_num'])
  #       @inbound_notification.inbound_skus.each do |inbound_sku|
  #         inbound_sku.inbound_received_skus.create!(inbound_received_info_id: @inbound_received_info.id, quantity: inbound_sku.quantity)
  #         inbound_sku.inbound_batch_skus.create!(inbound_batch_id: @inbound_batch.id, quantity: inbound_sku.quantity)
  #       end
  #       remote_inventory_register(@inbound_batch)  # >> CALL API
  #     end
  #
  #     { status: 'succ', data: @inbound_notification.to_api }.to_json
  #   end
  # end

  # 2.1.15 入库预报关闭 ADMIN
  post :close, :map => ':id/close', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_notification

      if @inbound_notification.can_close?
        ActiveRecord::Base.transaction do
          @inbound_notification.update!(status: 'closed')
          if @inbound_notification.inbound_type == 'transfer'
            @inbound_notification.finish_transfer_task  # 待验证
            @inbound_notification.update!(status: 'finished')  # transfer 类型直接 closed => finished
          end
        end
      else
        raise t('api.errors.inbound_notification.cannot_operate', :id => params[:id])
      end
      { status: 'succ', data: @inbound_notification.to_api }.to_json
    end
  end

  # 2.1.16 入库预报重新打开 ADMIN
  post :reopen, :map => ':id/reopen', :provides => [:json] do
    api_rescue do
      authenticate_access_token
      load_inbound_notification

      if @inbound_notification.can_reopen?
        @inbound_notification.update!(status: 'reopened')
      else
        raise t('api.errors.inbound_notification.cannot_operate', :id => params[:id])
      end
      { status: 'succ', data: @inbound_notification.to_api }.to_json
    end
  end


end