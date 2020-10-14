# encoding: utf-8
class InventoryTaskCheckType < ActiveRecord::Base
  belongs_to :inventory_task, :class_name => 'InventoryTask'
  belongs_to :inventory,      :class_name => 'Inventory'

  validates_inclusion_of :check_type,  :in => %w[sku shelf]
  validates_presence_of :inventory_id, :if => :check_type_is_sku
  validates_presence_of :shelf_num,    :if => :check_type_is_shelf

  def to_api
    case check_type
      when 'sku'   then to_api_sku
      when 'shelf' then to_api_shelf
      else {}
    end
  end

  def to_api_sku
    {
      inventory_id: inventory_id,
      inventory_task_id: inventory_task_id,
      check_type:   check_type,
      sku_code:     inventory.sku_code,
      barcode:      inventory.barcode,
      account_id:   inventory.account_id,
      sku_owner:    inventory.account.email,
      shelf_nums:   inventory.inventory_infos.remain.pluck(:shelf_num).uniq
    }
  end

  def to_api_shelf
    { check_type: check_type, shelf_num: shelf_num }
  end

  private
  def check_type_is_sku;   check_type == 'sku';   end
  def check_type_is_shelf; check_type == 'shelf'; end
end
