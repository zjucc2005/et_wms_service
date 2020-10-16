# encoding: utf-8
class InventoryTaskTransferInfo < ActiveRecord::Base
  belongs_to :inventory_task, :class_name => 'InventoryTask'
  belongs_to :inventory,      :class_name => 'Inventory'

  before_validation :setup, :on => :create
  # before_validation :validate_to_shelf_num, :on => :update

  validates_inclusion_of    :status, :in => %w[new finished cancelled]
  validates_presence_of     :inventory_task_id
  validates_presence_of     :inventory_id
  validates_presence_of     :to_depot_code
  validates_presence_of     :from_shelf_num
  validates_numericality_of :transfer_quantity, :greater_than => 0, :only_integer => true

  # before_update :set_status
  # after_update  :update_parent_status

  def to_api
    {
      id: id,
      inventory_id:      inventory_id,
      inventory_task_id: inventory_task_id,
      status:            status,
      sku_code:          inventory.try(:sku_code),
      barcode:           inventory.try(:barcode),
      to_depot_code:     to_depot_code,
      from_shelf_num:    from_shelf_num,
      # to_shelf_num:      to_shelf_num,
      transfer_quantity: transfer_quantity,
      # operator:          operator,
      created_at:        created_at,
      updated_at:        updated_at
    }
  end

  def to_inbound_notification
    {
      sku_code: inventory.sku_code,
      barcode: inventory.barcode,
      account_id: inventory.account_id,
      quantity: transfer_quantity
    }
  end

  # 根据日志记录进行后续操作, 扣除冻结数量
  def execute_transfer_task
    operation_logs = InventoryOperationLog.where(operation: 'freeze', remark: 'transfer task', reference_id: self.id)

    # 如果出现数据对不上的情况, 记录下来, 用于后续查询
    unless operation_logs.sum(:quantity) == transfer_quantity
      logger.warn "transfer quantity not match, [self: #{transfer_quantity}, logs: #{operation_logs.sum(:quantity)}]"
    end

    operation_logs.each do |operation_log|
      inventory_info = inventory.inventory_infos.where(shelf_num: from_shelf_num, batch_num: operation_log.batch_num).first

      transfer_quantity = operation_log.quantity
      # transaction
      inventory_info.quantity        -= transfer_quantity
      inventory_info.frozen_quantity -= transfer_quantity
      inventory_info.save!
      inventory.quantity             -= transfer_quantity
      inventory.frozen_quantity      -= transfer_quantity
      inventory.save!

      # 更新转移操作日志, 冻结 => 扣除
      operation_log.update!(operation: 'transfer', quantity: -transfer_quantity)
    end

    self.update!(status: 'finished')
  end

  def cancel_transfer_task
    operation_logs = InventoryOperationLog.where(operation: 'freeze', remark: 'transfer task', reference_id: self.id)
    operation_logs.each do |operation_log|
      inventory_info = inventory.inventory_infos.where(shelf_num: operation_log.shelf_num, batch_num: operation_log.batch_num).first
      unfreeze_quantity = operation_log.quantity
      inventory_info.available_quantity += unfreeze_quantity
      inventory_info.frozen_quantity    -= unfreeze_quantity
      inventory_info.save!
      inventory.available_quantity      += unfreeze_quantity
      inventory.frozen_quantity         -= unfreeze_quantity
      inventory.save!
      inventory_info.create_operation_log!(operation: 'unfreeze', quantity: unfreeze_quantity, remark: 'transfer task',
                                           reference_id: self.id, operator_id: inventory.account_id, operator: inventory.account.email)
    end
    self.update!(status: 'cancelled')
  end

  private
  def setup
    self.status = 'new'
  end

  # 更新任务状态
  # def set_status
  #   if self.status != 'cancelled'
  #     self.status = to_shelf_num.present? ? 'finished' : 'new'
  #   end
  # end
  #
  # def update_parent_status
  #   inventory_task.update_status
  # end

  # def validate_to_shelf_num
  #   if to_shelf_num.present?
  #     if to_shelf_num.start_with? to_depot_code
  #       depot = Depot.where(depot_code: to_depot_code).first
  #       errors.add(:to_shelf_num, :invalid) unless depot && depot.has_shelf_num?(to_shelf_num)
  #     else
  #       errors.add(:to_shelf_num, :invalid)
  #     end
  #   end
  # end

end
