# encoding: utf-8
class Inventory::Operation
  class << self

    def register_operation(resource, operator=nil)
      begin
        validate_register_resource(resource)

        logger.info "inventory register operation start! BatchNum[#{resource['batch_num']}]"

        ActiveRecord::Base.transaction do
          resource['inbound_batch_skus'].each do |inbound_batch_sku|
            inbound_batch_sku['quantity'] = Integer(inbound_batch_sku['quantity'])

            # 查找现有的 Inventory 实例, 如果没有, 新建一个实例
            inventory = Inventory.where(sku_code: inbound_batch_sku['sku_code'], barcode: inbound_batch_sku['barcode'], sku_owner: inbound_batch_sku['sku_owner']).first
            if inventory.nil?
              inventory = Inventory.create!(
                sku_code:     inbound_batch_sku['sku_code'],
                barcode:      inbound_batch_sku['barcode'],
                sku_owner:    inbound_batch_sku['sku_owner'],
                channel:      inbound_batch_sku['channel'],
                name:         inbound_batch_sku['name'],
                foreign_name: inbound_batch_sku['foreign_name'],
                quantity:           0,
                available_quantity: 0,
                frozen_quantity:    0,
                abc_category: inbound_batch_sku['abc_category']
              )
            end

            # 插入批次 InventoryInfo
            inventory_info = inventory.inventory_infos.create!(
              batch_num:          resource['batch_num'],
              quantity:           inbound_batch_sku['quantity'],
              available_quantity: inbound_batch_sku['quantity'],
              frozen_quantity:    0,
              shelf_num:          nil,
              depot_code:         resource['depot_code'],
              production_date:    inbound_batch_sku['production_date'],
              expiry_date:        inbound_batch_sku['expiry_date'],
              country_of_origin:  inbound_batch_sku['country_of_origin']
            )

            # 更新库存数量
            prev_quantity           = inventory.quantity
            prev_available_quantity = inventory.available_quantity

            inventory.update!(
              quantity:           inbound_batch_sku['quantity'] + prev_quantity,
              available_quantity: inbound_batch_sku['quantity'] + prev_available_quantity
            )

            inventory_info.create_operation_log!(operation: 'register', quantity: inbound_batch_sku['quantity'], remark: 'SYS_CALL: register operation', operator: operator)
            logger.info "inventory register operation -- SkuCode[#{inbound_batch_sku['sku_code']}], Quantity[#{prev_quantity}]=>[#{inventory.quantity}]"
          end
        end

        true  # return
      rescue Exception => e
        logger.info "inventory register operation failure! reason: #{e.message}"
        raise e.message
      end
    end

    def register_decrease_operation(resource, operator=nil)
      begin
        validate_register_decrease_resource(resource)

        logger.info "inventory register decrease operation start! BatchNum[#{resource['batch_num']}]"

        ActiveRecord::Base.transaction do
          resource['quantity'] = Integer(resource['quantity'])

          # 查找对应的批次
          inventory = Inventory.where(sku_code: resource['sku_code'], barcode: resource['barcode'], sku_owner: resource['sku_owner']).first
          raise "inventory with sku_code [#{resource['sku_code']}] not found" if inventory.nil?
          inventory_info = inventory.inventory_infos.where(batch_num: resource['batch_num']).first
          raise "inventory_info with batch_num [#{resource['batch_num']}] not found" if inventory_info.nil?
          raise 'there is not enough inventory to operate' if resource['quantity'] > inventory_info.available_quantity

          # 更新库存数量
          prev_quantity           = inventory.quantity
          prev_available_quantity = inventory.available_quantity

          inventory.update!(
            quantity:           prev_quantity - resource['quantity'],
            available_quantity: prev_available_quantity - resource['quantity']
          )
          inventory_info.quantity           -= resource['quantity']
          inventory_info.available_quantity -= resource['quantity']
          inventory_info.save!

          inventory_info.create_operation_log!(operation: 'register_decrease', quantity: resource['quantity'], remark: resource['memo'], operator: operator)
          logger.info "inventory register decrease operation -- SkuCode[#{resource['sku_code']}], Quantity[#{prev_quantity}]=>[#{inventory.quantity}]"
        end

        true  # return
      rescue Exception => e
        logger.info "inventory register decrease operation failure! reason: #{e.message}"
        raise e.message
      end
    end

    def unregister_operation(resource, operator=nil)
      begin
        validate_unregister_resource(resource)

        logger.info "inventory unregister operation start! BatchNum[#{resource['batch_num']}]"

        ActiveRecord::Base.transaction do
          # 已有其他(登记除外)记录则不能取消库存登记
          other_logs = InventoryOperationLog.where(batch_num: resource['batch_num']).where.not(operation: 'register')
          raise 'other operation logs existed' if other_logs.count > 0
          register_logs = InventoryOperationLog.where(batch_num: resource['batch_num'], operation: 'register')
          register_logs.delete_all

          # 查找对应的批次, 删除对应的批次和register日志
          inventory_infos = InventoryInfo.where(batch_num: resource['batch_num'])
          inventory_infos.each do |inventory_info|
            inventory = inventory_info.inventory

            # 更新库存数量
            prev_quantity           = inventory.quantity
            prev_available_quantity = inventory.available_quantity

            inventory.update!(
              quantity:           prev_quantity - inventory_info.quantity,
              available_quantity: prev_available_quantity - inventory_info.available_quantity
            )
            inventory_info.destroy
            logger.info "inventory unregister operation -- SkuCode[#{inventory_info.sku_code}], Quantity[#{prev_quantity}]=>[#{inventory.quantity}]"
          end
        end

        true  # return
      rescue Exception => e
        logger.info "inventory unregister operation failure! reason: #{e.message}"
        raise e.message
      end
    end

    def mount_operation(resource, operator=nil)
      begin
        validate_mount_resource(resource)

        logger.info "inventory mount operation start! BatchNum[#{resource['batch_num']}]"

        ActiveRecord::Base.transaction do
          resource['quantity'] = Integer(resource['quantity'])

          # 给登记的库存分配货架号, 库存总量不变
          inventory = Inventory.where(sku_code: resource['sku_code'], barcode: resource['barcode'], sku_owner: resource['sku_owner']).first
          raise 'inventory not found' if inventory.nil?

          inventory_info = inventory.inventory_infos.where(batch_num: resource['batch_num'], shelf_num: nil, depot_code: resource['depot_code']).first
          raise 'inventory_info not found' if inventory_info.nil?

          if resource['quantity'] <= inventory_info.quantity
            mount_inventory_info = inventory.inventory_infos.create!(
              batch_num:          resource['batch_num'],
              quantity:           resource['quantity'],
              available_quantity: resource['quantity'],
              frozen_quantity:    0,
              shelf_num:          resource['shelf_num'],
              depot_code:         resource['depot_code'],
              production_date:    inventory_info.production_date,
              expiry_date:        inventory_info.expiry_date,
              country_of_origin:  inventory_info.country_of_origin
            )
            prev_quantity           = inventory_info.quantity
            prev_available_quantity = inventory_info.available_quantity
            inventory_info.update!(
              quantity:           prev_quantity - resource['quantity'],
              available_quantity: prev_available_quantity - resource['quantity']
            )

            mount_inventory_info.create_operation_log!(operation: 'mount', quantity: resource['quantity'], remark: 'SYS_CALL: mount operation', operator: operator)
            logger.info "inventory mount operation -- SkuCode[#{resource['sku_code']}], [#{resource['quantity']}]"
          else
            raise 'not enough quantity to mount'
          end
        end

        true  # return
      rescue Exception => e
        logger.info "inventory mount operation failure! reason: #{e.message}"
        raise e.message
      end
    end

    def outbound_operation(resource, operator=nil)
      begin
        validate_outbound_resource(resource)

        logger.info "inventory outbound operation start! BatchNum[#{resource['batch_num']}], OrderNum[#{resource['order_num']}]"
        ActiveRecord::Base.transaction do
          resource['outbound_skus'].each do |outbound_sku|
            inventory = Inventory.where(sku_code: outbound_sku['sku_code'], barcode: outbound_sku['barcode'], sku_owner: outbound_sku['sku_owner']).first
            prev_quantity = inventory.quantity
            outbound_sku['operate_infos'].each do |operate_info|
              operate_info['quantity'] = Integer(operate_info['quantity'])
              inventory_info = inventory.inventory_infos.remain.where(shelf_num: operate_info['shelf_num'], batch_num: operate_info['batch_num']).first

              # 同一出库批次号, 重复调用不产生新的下架记录
              next if inventory_info.operation_logs.where(operation: 'unmount', refer_num: resource['order_num']).present?

              # 下架操作顺序为 解冻(unfreeze) => 下架(unmount), 但只产生下架(unmount)日志
              inventory_info.unfreeze_inventory!(operate_info['quantity'])  # 解冻
              inventory_info.unmount_inventory!(operate_info['quantity'])   # 下架
              inventory_info.create_operation_log!(operation: 'unmount', quantity: operate_info['quantity'], refer_num: resource['order_num'], remark: 'SYS_CALL: outbound operation', operator: operator)

              logger.info "inventory outbound operation success! SkuCode[#{outbound_sku['sku_code']}], Quantity[#{prev_quantity}]=>[#{inventory.quantity}]"
            end
          end
        end

        true  # return
      rescue Exception => e
        logger.info "inventory outbound operation failure! reason: #{e.message}"
        raise e.message
      end
    end

    def get_picking_infos(resource, operator=nil)
      begin
        validate_get_picking_infos_resource(resource)

        result = {
          batch_num: resource['batch_num'],
          outbound_skus: []
        }

        ActiveRecord::Base.transaction do
          resource['outbound_skus'].each do |outbound_sku|
            inventory = Inventory.where(sku_code: outbound_sku['sku_code'], barcode: outbound_sku['barcode'], sku_owner: outbound_sku['sku_owner']).first
            raise "inventory with sku_code #{outbound_sku['sku_code']} not found" if inventory.nil?
            inventory_infos = inventory.inventory_infos.remain
            outbound_sku['quantity'] = Integer(outbound_sku['quantity'])
            if inventory_infos.sum(:available_quantity) < outbound_sku['quantity']
              raise "inventory with sku_code #{outbound_sku['sku_code']} not enough to pick, expected: #{outbound_sku['quantity']}, actual: #{inventory_infos.sum(:available_quantity)}"
            end

            operate_infos = Array.new

            rest_of_freeze_quantity = outbound_sku['quantity']
            # 按照有货架号优先 + 先入先出原则

            # 有货架号
            inventory_infos.where.not(shelf_num: nil).order(:created_at => :asc).each do |inventory_info|
              if rest_of_freeze_quantity <= 0
                break
              elsif rest_of_freeze_quantity < inventory_info.available_quantity
                _freeze_quantity_ = rest_of_freeze_quantity
              else
                _freeze_quantity_ = inventory_info.available_quantity
              end
              inventory_info.freeze_inventory!(_freeze_quantity_)
              inventory_info.create_operation_log!(operation: 'freeze', quantity: outbound_sku['quantity'], refer_num: resource['batch_num'], remark: 'SYS_CALL: get picking infos', operator: operator)

              operate_infos << { shelf_num: inventory_info.shelf_num, quantity: _freeze_quantity_, batch_num: inventory_info.batch_num }.stringify_keys
              rest_of_freeze_quantity -= _freeze_quantity_
            end

            # 无货架号
            inventory_infos.where(shelf_num: nil).order(:created_at => :asc).each do |inventory_info|
              if rest_of_freeze_quantity <= 0
                break
              elsif rest_of_freeze_quantity < inventory_info.available_quantity
                _freeze_quantity_ = rest_of_freeze_quantity
              else
                _freeze_quantity_ = inventory_info.available_quantity
              end
              inventory_info.freeze_inventory!(_freeze_quantity_)
              inventory_info.create_operation_log!(operation: 'freeze', quantity: outbound_sku['quantity'], refer_num: resource['batch_num'], remark: 'SYS_CALL: get picking infos', operator: operator)

              operate_infos << { shelf_num: inventory_info.shelf_num, quantity: _freeze_quantity_, batch_num: inventory_info.batch_num }.stringify_keys
              rest_of_freeze_quantity -= _freeze_quantity_
            end

            result[:outbound_skus] << {
              sku_code: outbound_sku['sku_code'],
              barcode: outbound_sku['barcode'],
              sku_owner: outbound_sku['sku_owner'],
              operate_infos: operate_infos
            }
          end
        end

        result  # return
      rescue Exception => e
        logger.info "inventory get_picking_infos failure! reason: #{e.message}"
        raise e.message
      end
    end

    def remove_picking_infos(resource, operator=nil)
      begin
        validate_remove_picking_infos_resource(resource)

        ActiveRecord::Base.transaction do
          resource['outbound_skus'].each do |outbound_sku|
            inventory = Inventory.where(sku_code: outbound_sku['sku_code'], barcode: outbound_sku['barcode'], sku_owner: outbound_sku['sku_owner']).first
            outbound_sku['operate_infos'].each do |operate_info|
              operate_info['quantity'] = Integer(operate_info['quantity'])
              inventory_info = inventory.inventory_infos.remain.where(shelf_num: operate_info['shelf_num'], batch_num: operate_info['batch_num']).first
              inventory_info.unfreeze_inventory!(operate_info['quantity'])  # 解冻
              inventory_info.create_operation_log!(operation: 'unfreeze', quantity: operate_info['quantity'], refer_num: resource['batch_num'], remark: 'SYS_CALL: remove picking infos', operator: operator)
            end
          end
        end

        true  # return
      rescue Exception => e
        logger.info "inventory remove_picking_infos failure! reason: #{e.message}"
        raise e.message
      end
    end

    def modify_operation(resource, operator=nil)
      begin
        validate_modify_resource(resource)

        logger.info "inventory mount operation start! InventoryId[#{resource['inventory_id']}], ShelfNum[#{resource['shelf_num']}], Quantity[#{resource['quantity']}]"

        ActiveRecord::Base.transaction do
          resource['quantity'] = Integer(resource['quantity'])

          # 找出库存
          inventory = Inventory.where(id: resource['inventory_id']).first
          raise 'inventory not found' if inventory.nil?

          # 找出对应货架库存, 创建批改前日志
          freeze_quantity = 0
          before_quantity = 0
          after_quantity  = resource['quantity']
          depot_code      = ''
          inventory.inventory_infos.remain.where(shelf_num: resource['shelf_num']).each do |info|
            depot_code       = info.depot_code
            freeze_quantity += info.frozen_quantity
            before_quantity += info.quantity
            info.update!(quantity: 0, available_quantity: 0, frozen_quantity: 0)
          end

          # 批改后新批次
          inventory.inventory_infos.create!(
            quantity:           after_quantity,
            available_quantity: after_quantity - freeze_quantity,
            frozen_quantity:    freeze_quantity,
            batch_num:          "MDF#{Time.now.strftime('%y%m%d%H%M%S')}",  # 批次号 MDF + timestamp
            shelf_num:          resource['shelf_num'],
            depot_code:         depot_code
          )

          # 创建批改前后日志
          inventory.create_operation_log!(operation: 'modify', remark: 'before', shelf_num: resource['shelf_num'], quantity: before_quantity, operator: operator)
          inventory.create_operation_log!(operation: 'modify', remark: 'after',  shelf_num: resource['shelf_num'], quantity: after_quantity,  operator: operator)
          # 更新库存总量
          inventory_infos = inventory.inventory_infos.remain
          inventory.update!(
            quantity:           inventory_infos.sum(:quantity),
            available_quantity: inventory_infos.sum(:available_quantity),
            frozen_quantity:    inventory_infos.sum(:frozen_quantity)
          )
        end

        true
      rescue Exception => e
        logger.info "inventory modify operation failure! reason: #{e.message}"
        raise e.message
      end
    end

    private
    # def validate_inbound_resource(resource)
    #   %w[batch_num sku_code barcode sku_owner quantity shelf_num depot_code].each do |field|
    #     raise I18n.t('api.errors.blank', :field => field) if resource[field].blank?
    #   end
    #
    #   quantity = Integer(resource['quantity']) rescue raise(I18n.t('api.errors.not_an_integer', :field => 'Quantity'))
    #   raise I18n.t('api.errors.greater_than', :field => 'Quantity', :value => 0) if quantity <= 0
    #   shelf_info = ShelfInfo.where(shelf_num: resource['shelf_num']).first
    #   raise I18n.t('api.errors.shelf_info.not_found') if shelf_info.nil?
    #   raise I18n.t('api.errors.shelf_info.not_found') if shelf_info.shelf.depot_code != resource['depot_code']
    #   true  # return
    # end

    def validate_register_resource(resource)
      %w[batch_num depot_code inbound_batch_skus].each do |field|
        raise I18n.t('api.errors.blank', :field => field) if resource[field].blank?
      end
      if Array === resource['inbound_batch_skus']
        resource['inbound_batch_skus'].each_with_index do |inbound_batch_sku, index|
          raise I18n.t('api.errors.not_hash', :field => "inbound_batch_skus[#{index}]") unless Hash === inbound_batch_sku
          %w[sku_code barcode name foreign_name sku_owner quantity].each do |field|
            raise I18n.t('api.errors.blank', :field => "inbound_batch_skus[#{index}].#{field}") if inbound_batch_sku[field].blank?
          end

          quantity = Integer(inbound_batch_sku['quantity']) rescue raise(I18n.t('api.errors.not_an_integer', :field => "inbound_batch_skus[#{index}].quantity"))
          raise I18n.t('api.errors.greater_than', :field => "inbound_batch_skus[#{index}].quantity", :value => 0) if quantity <= 0
        end
      else
        raise I18n.t('api.errors.not_array', :field => 'inbound_batch_skus')
      end
      true  # return
    end

    def validate_register_decrease_resource(resource)
      %w[batch_num sku_code barcode sku_owner quantity].each do |field|
        raise I18n.t('api.errors.blank', :field => field) if resource[field].blank?
      end

      quantity = Integer(resource['quantity']) rescue raise(I18n.t('api.errors.not_an_integer', :field => 'quantity'))
      raise I18n.t('api.errors.greater_than', :field => 'quantity', :value => 0) if quantity <= 0
      true  # return
    end

    def validate_unregister_resource(resource)
      %w[batch_num].each do |field|
        raise I18n.t('api.errors.blank', :field => field) if resource[field].blank?
      end
      true  # return
    end

    def validate_mount_resource(resource)
      %w[batch_num sku_code barcode sku_owner quantity shelf_num depot_code].each do |field|
        raise I18n.t('api.errors.blank', :field => field) if resource[field].blank?
      end

      quantity = Integer(resource['quantity']) rescue raise(I18n.t('api.errors.not_an_integer', :field => 'quantity'))
      raise I18n.t('api.errors.greater_than', :field => 'quantity', :value => 0) if quantity <= 0
      shelf_info = ShelfInfo.where(shelf_num: resource['shelf_num']).first
      raise I18n.t('api.errors.shelf_info.not_found') if shelf_info.nil?
      raise I18n.t('api.errors.shelf_info.not_found') if shelf_info.shelf.depot_code != resource['depot_code']
      true  # return
    end

    def validate_outbound_resource(resource)
      %w[batch_num order_num outbound_skus].each do |field|
        raise I18n.t('api.errors.blank', :field => field) if resource[field].blank?
      end
      if Array === resource['outbound_skus']
        resource['outbound_skus'].each_with_index do |outbound_sku, index|
          raise I18n.t('api.errors.not_hash', :field => "outbound_skus[#{index}]") unless Hash === outbound_sku
          %w[sku_code barcode sku_owner operate_infos].each do |field|
            raise I18n.t('api.errors.blank', :field => "outbound_skus[#{index}].#{field}") if outbound_sku[field].blank?
          end
        end
      else
        raise I18n.t('api.errors.not_array', :field => 'outbound_skus')
      end
      true  # return
    end

    def validate_get_picking_infos_resource(resource)
      %w[batch_num outbound_skus].each do |field|
        raise I18n.t('api.errors.blank', :field => field) if resource[field].blank?
      end
      if Array === resource['outbound_skus']
        resource['outbound_skus'].each_with_index do |outbound_sku, index|
          raise I18n.t('api.errors.not_hash', :field => "outbound_skus[#{index}]") unless Hash === outbound_sku
          %w[sku_code barcode sku_owner quantity].each do |field|
            raise I18n.t('api.errors.blank', :field => "outbound_skus[#{index}].#{field}") if outbound_sku[field].blank?
          end
        end
      else
        raise I18n.t('api.errors.not_array', :field => 'outbound_skus')
      end
      true  # return
    end

    def validate_remove_picking_infos_resource(resource)
      %w[batch_num outbound_skus].each do |field|
        raise I18n.t('api.errors.blank', :field => field) if resource[field].blank?
      end
      if Array === resource['outbound_skus']
        resource['outbound_skus'].each_with_index do |outbound_sku, index|
          raise I18n.t('api.errors.not_hash', :field => "outbound_skus[#{index}]") unless Hash === outbound_sku
          %w[sku_code barcode sku_owner operate_infos].each do |field|
            raise I18n.t('api.errors.blank', :field => "outbound_skus[#{index}].#{field}") if outbound_sku[field].blank?
          end
        end
      else
        raise I18n.t('api.errors.not_array', :field => 'outbound_skus')
      end
      true  # return
    end

    def validate_modify_resource(resource)
      %w[inventory_id shelf_num quantity].each do |field|
        raise I18n.t('api.errors.blank', :field => field) if resource[field].blank?
      end
      quantity = Integer(resource['quantity']) rescue raise(I18n.t('api.errors.not_an_integer', :field => 'quantity'))
      raise I18n.t('api.errors.greater_than_or_equal_to', :field => 'quantity', :value => 0) if quantity < 0
      shelf_info = ShelfInfo.where(shelf_num: resource['shelf_num']).first
      raise I18n.t('api.errors.shelf_info.not_found') if shelf_info.nil?
      true
    end
  end
end