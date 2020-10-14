# encoding: utf-8
class InventoryTaskCheckInfo < ActiveRecord::Base
  belongs_to :inventory_task, :class_name => 'InventoryTask'
  belongs_to :inventory,      :class_name => 'Inventory'

  before_validation :setup, :on => :create
  before_update :set_status
  after_update  :update_parent_status

  validates_inclusion_of    :status, :in => %w[new finished cancelled]
  validates_presence_of     :inventory_task_id
  validates_presence_of     :inventory_id
  validates_presence_of     :shelf_num
  validates_numericality_of :check_quantity, :greater_than_or_equal_to => 0, :only_integer => true, :allow_nil => true

  def to_api
    {
      id: id,
      inventory_id:   inventory_id,
      status:         status,
      sku_code:       inventory.try(:sku_code),
      barcode:        inventory.try(:barcode),
      shelf_num:      shelf_num,
      quantity:       quantity ,
      check_quantity: check_quantity,
      operator_id:    operator_id,
      operator:       operator,
      created_at:     created_at,
      updated_at:     updated_at
    }
  end

  def quantity
    if inventory_task.status == 'finished'
      InventoryOperationLog.where(remark: 'create check', reference_id: id).sum(:quantity)  # operation log data
    else
      inventory.inventory_infos.where(shelf_num: shelf_num).sum(:quantity)  # real time data
    end
  end

  def create_operation_log!(hash)
    inventory.create_operation_log!(
               hash.merge({ shelf_num: shelf_num, reference_id:id, operator_id: operator_id, operator: operator })
    )
  end

  def execute_check_task
    #创建盘点前日志
    freeze_quantity = 0
    depot_code = ""
    inventory.inventory_infos.remain.where(shelf_num:shelf_num).each do |info|
      depot_code = info.depot_code
      self.create_operation_log!({ operation: 'check', remark: 'create check', quantity: quantity, batch_num: batch_num })
      freeze_quantity += info.frozen_quantity
      info.update!(quantity:0,available_quantity:0,frozen_quantity:0)
    end
    #合并批次
    inventory.inventory_infos.create!(quantity:check_quantity,available_quantity:check_quantity-freeze_quantity,
      frozen_quantity: freeze_quantity, batch_num: self.gen_batch_num, shelf_num: shelf_num, depot_code: depot_code)
    #更新商品数量
    inventory_infos = inventory.inventory_infos.remain
    inventory.update!(quantity:inventory_infos.sum(:quantity),
      available_quantity:inventory_infos.sum(:available_quantity),
      frozen_quantity:inventory_infos.sum(:frozen_quantity)
      )
    #创建盘点后日志
    self.create_operation_log!({ operation: 'check', remark: 'finish check', quantity: check_quantity, batch_num: self.gen_batch_num })
  end

  # 生成盘点后的库存批次号
  def gen_batch_num
    "CHK#{sprintf('%08d', self.id)}"
  end

  def cancel_check_task
    self.update!(status: 'cancelled')
  end

  private
  def setup
    self.status = 'new'
    # errors.add(:inventory_id, :not_authorized) unless inventory_task.try(:sku_owner) == inventory.try(:sku_owner)
  end

  def set_status
    if self.status != 'cancelled'
      self.status = check_quantity.present? ? 'finished' : 'new'
    end
  end

  def update_parent_status
    inventory_task.update_status
  end

end
