# encoding: utf-8
class Inventory < ActiveRecord::Base
  extend QueryFilter

  belongs_to :account, :class_name => 'Account'

  has_many :inventory_infos, :class_name => 'InventoryInfo', :dependent => :destroy
  has_many :transfer_infos, :class_name => 'InventoryTaskTransferInfo'
  has_many :check_infos, :class_name => 'InventoryTaskCheckInfo'
  has_many :operation_logs, :class_name => 'InventoryOperationLog'

  before_validation :validates_uniqueness_of_sku_code

  validates_presence_of :sku_code
  validates_presence_of :barcode
  validates_uniqueness_of :barcode
  validates_numericality_of :quantity,           :greater_than_or_equal_to => 0, :only_integer => true
  validates_numericality_of :available_quantity, :greater_than_or_equal_to => 0, :only_integer => true
  validates_numericality_of :frozen_quantity,    :greater_than_or_equal_to => 0, :only_integer => true
  validates_numericality_of :caution_threshold,  :greater_than_or_equal_to => 0, :only_integer => true, :allow_nil => true

  def to_api
    {
      id: id,
      account_id:         account_id,
      sku_owner:          account.email,
      channel:            channel,
      sku_code:           sku_code,
      barcode:            barcode,
      name:               name,
      foreign_name:       foreign_name,
      abc_category:       abc_category,
      quantity:           quantity,
      available_quantity: available_quantity,
      frozen_quantity:    frozen_quantity,
      caution_threshold:  caution_threshold || global_caution_threshold || 0,
      created_at:         created_at,
      updated_at:         updated_at
    }
  end

  # 包含部分统计值的 to_api
  def to_api_with_statistics
    to_api.merge(outbound_last_month: outbound_last_month)
  end

  # 库存详情页用的字段
  def to_api_show_top_right
    {
      quantity:            quantity,
      depot_code:          inventory_infos.last.try(:depot_code),
      outbound_last_month: outbound_last_month,
      caution_threshold:   caution_threshold || global_caution_threshold || 0,
      last_checked_at:     last_checked_at
    }
  end

  def global_caution_threshold
    InventorySetting.personal_settings(account_id)['global_caution_threshold']
  end

  # 上月出库量统计
  # 数值不会变化, 增加统计表存入统计结果, 可增加性能
  def outbound_last_month
    current_month = Time.now.beginning_of_month
    last_month    = current_month - 1.month
    operation_logs.where(operation: 'unmount').where('created_at BETWEEN ? and ?', last_month, current_month).sum(:quantity)
  end

  # 最后盘点时间
  def last_checked_at
    self.check_infos.where(status: 'finished').order(:created_at => :desc).pluck(:created_at).first
  end

  # 自动冻结转移任务部分的库存, 外层事务
  def create_transfer_task!(transfer_quantity, inventory_task_id, to_depot_code, operator=nil)
    operator ||= self.account
    transfer_quantity = transfer_quantity.to_i
    if transfer_quantity <= 0
      raise 'transfer quantity must be greater than 0'
    elsif available_quantity < transfer_quantity
      raise "transfer quantity must be less than or equal to #{available_quantity}"
    end

    # 优先选择入库时间早的
    rest_of_transfer_quantity = transfer_quantity
    inventory_infos.where('available_quantity > 0').order(:created_at => :asc).each do |inventory_info|
      if rest_of_transfer_quantity <= 0
        break
      elsif rest_of_transfer_quantity >= inventory_info.available_quantity
        freeze_quantity = inventory_info.available_quantity
      else
        freeze_quantity = rest_of_transfer_quantity
      end

      # 如果有相同货架号的批次, 则合并
      transfer_info = transfer_infos.where(inventory_task_id: inventory_task_id, from_shelf_num: inventory_info.shelf_num).first
      if transfer_info
        transfer_info.transfer_quantity += freeze_quantity
        transfer_info.save!
      else
        transfer_info = transfer_infos.create!(
          inventory_task_id: inventory_task_id, to_depot_code: to_depot_code,
          from_shelf_num: inventory_info.shelf_num, transfer_quantity: freeze_quantity)
      end

      # 更新库存相关数量 & 记录操作日志
      inventory_info.freeze_inventory!(freeze_quantity)
      inventory_info.create_operation_log!(operation: 'freeze', quantity: freeze_quantity, remark: 'transfer task', reference_id: transfer_info.id, operator_id: operator.id, operator: operator.email)

      rest_of_transfer_quantity -= freeze_quantity
    end
  end

  def create_check_task!(shelf_num, inventory_task_id)
    check_infos.create!(shelf_num:shelf_num, inventory_task_id: inventory_task_id)
  end

  def self.auto_create_check_task(inventory_task_id, account_id)
    # load inventory settings
    personal_settings = InventorySetting.personal_settings(account_id)
    #按种类各自盘点
    ["A", "B", "C", nil].each do |abc_category|
      check_frequency_yearly = case abc_category
                               when 'A' then personal_settings['check_frequency_yearly_cat_a']
                               when 'B' then personal_settings['check_frequency_yearly_cat_b']
                               when 'C' then personal_settings['check_frequency_yearly_cat_c']
                               else personal_settings['check_frequency_yearly_default']
                             end
      #未盘点商品
      all_invs = Inventory.where(abc_category: abc_category)
      all_invs = all_invs.where(account_id: account_id) if account_id
      check_infos = InventoryTaskCheckInfo.where('created_at >= ?', Time.now.beginning_of_year)
      checked_invs_id = check_infos.pluck(:inventory_id).uniq
      checked_invs = all_invs.where(id:checked_invs_id)
      rest_of_invs = all_invs - checked_invs

      #剩余盘点次数
      check_infos_id = check_infos.map{|check_info|check_info.id unless check_info.try(:inventory_task).try(:check_type)}
      checked_times = InventoryTaskCheckInfo.where(id:check_infos_id).select("DATE(created_at)").group("DATE(created_at)").count.size
      rest_check_times   = check_frequency_yearly - checked_times
      return nil if rest_check_times <= 0  # 达到计划盘点次数, 则直接返回

      # 自动盘点任务选择商品
      ratio = rest_of_invs.length / rest_check_times
      range = rest_of_invs.length % rest_check_times == 0 ? (ratio..ratio) : (ratio..ratio + 1)
      selected_invs = rest_of_invs.shuffle[0, rand(range)]
      selected_invs.each do |inv|
        inv.inventory_infos.map{|info| inv.create_check_task!(info.shelf_num, inventory_task_id) }
      end
    end
  end

  # 库存冻结操作, 按批次*货架记录冻结日志
  def inventory_freeze(freeze_quantity, batch_num=nil, shelf_num=nil, freeze_reason=nil, operator=nil)
    operator ||= self.account
    query_conditions = {}
    query_conditions[:batch_num] = batch_num if batch_num
    query_conditions[:shelf_num] = shelf_num if shelf_num
    query = inventory_infos.where(query_conditions).order(:created_at => :asc)  # 如果查询结果包含多个批次, 按升序依次冻结
    raise(I18n.t('api.errors.inventory_info.not_found')) if query.count.zero?        # 指定批次信息不存在时, 报错

    if query.sum(:available_quantity) < freeze_quantity
      errors.add(:available_quantity, :greater_than_or_equal_to, :count => freeze_quantity)
    else
      rest_of_freeze_quantity = freeze_quantity
      query.each do |inventory_info|
        if rest_of_freeze_quantity <= 0
          break
        elsif rest_of_freeze_quantity < inventory_info.available_quantity
          _freeze_quantity_ = rest_of_freeze_quantity
        else
          _freeze_quantity_ = inventory_info.available_quantity
        end
        inventory_info.freeze_inventory!(_freeze_quantity_)
        inventory_info.create_freeze_log!(_freeze_quantity_, freeze_reason, operator)
        rest_of_freeze_quantity -= _freeze_quantity_
      end
    end
  end

  # 待解冻日志查询
  def wait_to_unfreeze_logs
    operation_logs.where(operation: 'freeze', status: 'new')
  end

  # 通用日志
  def create_operation_log!(hash)
    self.operation_logs.create!(
      hash.merge({ sku_code: sku_code, barcode: barcode, account_id: account_id, channel: channel })
    )
  end

  private
  def validates_uniqueness_of_sku_code
    if Inventory.where(sku_code: sku_code, account_id: account_id).where.not(id: id).count > 0
      errors.add(:sku_code, :taken)
    end
  end

end
