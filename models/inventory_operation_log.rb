# encoding: utf-8
class InventoryOperationLog < ActiveRecord::Base
  extend QueryFilter

  belongs_to :account, :class_name => 'Account'
  belongs_to :inventory, :class_name => 'Inventory'

  validates_presence_of  :operation
  validates_inclusion_of :operation, :in => %w[register register_decrease mount unmount freeze unfreeze transfer check modify]
  validates_presence_of  :operator
  validates_presence_of  :sku_code, :barcode, :sku_owner
  validates_numericality_of :quantity, :only_integer => true

  before_validation :setup, :on => :create

  def to_api
    {
      id: id,
      account_id: account_id,
      sku_owner:  account.email,
      channel:    channel,
      inventory_id: inventory_id,
      operation:  operation,
      sku_code:   sku_code,
      barcode:    barcode,
      batch_num:  batch_num,
      shelf_num:  shelf_num,
      quantity:   quantity,
      operator:   operator,
      remark:     remark,
      refer_num:  refer_num,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  # 单个库存对应的日志, 不返回库存固有字段
  def to_api_simple
    {
      id: id,
      operation:  operation,
      # sku_code:   sku_code,
      # barcode:    barcode,
      # sku_owner:  sku_owner,
      # channel:    channel,
      batch_num:  batch_num,
      # shelf_num:  shelf_num,
      quantity:   quantity,
      # operator:   operator,
      # remark:     remark,
      refer_num:  refer_num,
      created_at: created_at,
      # updated_at: updated_at
    }
  end

  def inventory_unfreeze
    raise 'cannot unfreeze' unless operation == 'freeze' && status == 'new'
    ActiveRecord::Base.transaction do
      self_inventory_info = self.inventory_info
      if self_inventory_info.frozen_quantity >= quantity
        self_inventory_info.unfreeze_inventory!(quantity)
      else
        # 如果对应批次被合并, 则去找合并后的批次解冻
        create_check_log = inventory.operation_logs.where(operation: 'check', batch_num: batch_num, shelf_num: shelf_num, remark: 'create check').first
        raise 'check log not found' if create_check_log.nil?
        finish_check_log = InventoryOperationLog.where(operation: 'check', remark: 'finish check', reference_id: create_check_log.reference_id).first
        raise 'check log not found' if finish_check_log.nil?
        new_inventory_info = finish_check_log.inventory_info
        new_inventory_info.unfreeze_inventory!(quantity)
      end
      self.update!(status: nil)  # 去掉待解冻状态
    end
  end

  def inventory_info
    inventory.inventory_infos.where(batch_num: batch_num, shelf_num: shelf_num).first
  end

  # 上架操作回退, remote
  def inbound_batch_mount_rollback
    inbound_batch = InboundBatch.where(batch_num: self.batch_num).first
    raise 'inbound batch not found' if inbound_batch.nil?
    inbound_sku = inbound_batch.inbound_notification.inbound_skus.where(sku_code: sku_code, barcode: barcode, account_id: account_id).first
    raise 'inbound sku not found' if inbound_sku.nil?
    inbound_batch_sku = inbound_batch.inbound_batch_skus.where(inbound_sku_id: inbound_sku.id).first
    rollback_operate_infos = inbound_batch_sku.operate_infos.select do |info|
      info['operator_id'] == self.operator_id && info['quantity'] == self.quantity && info['shelf_num'] == self.shelf_num
    end
    if rollback_operate_infos.present?
      inbound_batch_sku.operate_infos -= rollback_operate_infos
      inbound_batch_sku.save!
      inbound_batch_sku.update_status!
      inbound_batch.update_status!
    end
  end

  private
  def setup
    self.operator ||= 'system'
  end

end
