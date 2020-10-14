# encoding: utf-8
class InventoryInfo < ActiveRecord::Base
  extend QueryFilter

  belongs_to :account, :class_name => 'Account'
  belongs_to :inventory, :class_name => 'Inventory'

  before_validation :setup, :on => :create

  validates_presence_of  :batch_num
  validates_inclusion_of :status, :in => %w[normal frozen partial_frozen]
  validates_presence_of  :sku_code, :barcode # :depot_code, :shelf_num
  validates_numericality_of :quantity,           :greater_than_or_equal_to => 0, :only_integer => true
  validates_numericality_of :available_quantity, :greater_than_or_equal_to => 0, :only_integer => true
  validates_numericality_of :frozen_quantity,    :greater_than_or_equal_to => 0, :only_integer => true

  scope :remain, lambda { where('quantity > 0') }

  before_save :set_status

  def to_api
    {
      id: id,
      account_id:         account_id,
      sku_owner:          account.email,
      inventory_id:       inventory_id,
      batch_num:          batch_num,
      status:             status,
      quantity:           quantity,
      available_quantity: available_quantity,
      frozen_quantity:    frozen_quantity,
      sku_code:           sku_code,
      barcode:            barcode,
      shelf_num:          shelf_num,
      depot_code:         depot_code,
      production_date:    production_date,
      expiry_date:        expiry_date,
      created_at:         created_at,
      updated_at:         updated_at
    }
  end

  # 通用日志
  def create_operation_log!(hash)
    inventory.operation_logs.create!(
      hash.merge({ sku_code: sku_code, barcode: barcode, account_id: account_id, channel: inventory.channel, batch_num: batch_num, shelf_num: shelf_num })
    )
  end

  # 手工冻结日志, 专用
  def create_freeze_log!(quantity, remark, operator)
    inventory.operation_logs.create!(
      operation: 'freeze', sku_code: sku_code, barcode: barcode, account_id: account_id, channel: inventory.channel, batch_num: batch_num,
      shelf_num: shelf_num, quantity: quantity, remark: remark, status: 'new', operator_id: operator.id, operator: operator.email
    )
  end

  def operation_logs
    inventory.operation_logs.where(batch_num: batch_num)
  end

  # 基础方法, 多处调用, 勿改动
  def freeze_inventory!(freeze_quantity)
    raise 'freeze_quantity must be less than or equal to available_quantity' if freeze_quantity > available_quantity
    self.available_quantity -= freeze_quantity
    self.frozen_quantity    += freeze_quantity
    self.save!
    inventory.available_quantity -= freeze_quantity
    inventory.frozen_quantity    += freeze_quantity
    inventory.save!
  end

  # 基础方法, 多处调用, 勿改动
  def unfreeze_inventory!(unfreeze_quantity)
    raise 'unfreeze_quantity must be less than or equal to frozen_quantity' if unfreeze_quantity > frozen_quantity
    self.available_quantity += unfreeze_quantity
    self.frozen_quantity    -= unfreeze_quantity
    self.save!
    inventory.available_quantity += unfreeze_quantity
    inventory.frozen_quantity    -= unfreeze_quantity
    inventory.save!
  end

  # 基础方法, 多出调用, 勿改动
  def unmount_inventory!(unmount_quantity)
    raise 'unmount_quantity must be less than or equal to available_quantity' if unmount_quantity > available_quantity
    self.available_quantity -= unmount_quantity
    self.quantity           -= unmount_quantity
    self.save!
    inventory.available_quantity -= unmount_quantity
    inventory.quantity           -= unmount_quantity
    inventory.save!
  end

  private
  def setup
    self.status     = 'normal'
    # abundant fields
    self.sku_code   = inventory.sku_code
    self.barcode    = inventory.barcode
    self.account_id = inventory.account_id
  end

  def set_status
    if frozen_quantity > 0
      self.status = available_quantity > 0 ? 'partial_frozen' : 'frozen'
    else
      self.status = 'normal'
    end
  end
end
