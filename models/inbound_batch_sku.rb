# encoding: utf-8
class InboundBatchSku < ActiveRecord::Base
  extend QueryFilter

  belongs_to :inbound_sku,   :class_name => 'InboundSku'
  belongs_to :inbound_batch, :class_name => 'InboundBatch'

  validates_inclusion_of  :status, :in => %w[new in_process finished]
  validates_numericality_of :quantity, :greater_than => 0

  before_validation :setup, :on => :create

  scope :normal, lambda { where(problem_type: nil) }

  def to_api
    {
      id: id,
      account_id:        inbound_sku.account_id,
      sku_code:          inbound_sku.sku_code,
      barcode:           inbound_sku.barcode,
      sku_owner:         inbound_sku.account.email,
      name:              inbound_sku.name,
      foreign_name:      inbound_sku.foreign_name,
      status:            status,
      quantity:          quantity,
      operate_infos:     operate_infos,  # 上架信息记录 [{shelf_num: 'DU-A-01-01-01', quantity: 10, operator: 'someone'},..]
      production_date:   production_date,
      expiry_date:       expiry_date,
      country_of_origin: country_of_origin,
      abc_category:      abc_category,
      problem_type:      problem_type,
      problem_memo:      problem_memo,
      operate_memo:      operate_memo,
      current_shelf:     current_shelf
    }
  end

  # 用于库存登记的格式
  def to_api_register
    {
      account_id:        inbound_sku.account_id,
      sku_code:          inbound_sku.sku_code,
      barcode:           inbound_sku.barcode,
      name:              inbound_sku.name,
      foreign_name:      inbound_sku.foreign_name,
      sku_owner:         inbound_sku.account.email,
      channel:           inbound_batch.inbound_notification.channel,
      quantity:          quantity,
      production_date:   production_date,
      expiry_date:       expiry_date,
      country_of_origin: country_of_origin,
      abc_category:      abc_category,
    }
  end

  def available_quantity
    quantity - operated_quantity
  end

  def operated_quantity
    if Array === operate_infos
      operate_infos.sum{|ele| ele['quantity']}
    else
      0
    end
  end

  def update_status!
    if available_quantity.zero?
      self.update!(status: 'finished')
    elsif available_quantity < quantity
      self.update!(status: 'in_process')
    else
      self.update!(status: 'new')
    end
  end

  def get_current_shelf
    inventory = inbound_sku.inventory
    raise 'inventory not found' if inventory.nil?
    shelf_nums = inventory.inventory_infos.remain.where.not(shelf_num: nil).pluck(:shelf_num).uniq
    self.current_shelf = shelf_nums
    self.save
    # begin
    #   helper = Class.new
    #   helper.extend EtInbound::App::BaseHelper
    #   helper.extend EtInbound::App::ApiHelper
    #
    #   params   = { sku_code: inbound_sku.sku_code, barcode: inbound_sku.barcode, sku_owner: inbound_sku.sku_owner }
    #   response = Api.get(helper.inventory_current_shelf_num_url, params)
    #   ret_data = JSON.parse response.body
    #   if ret_data['status'] == 'succ'
    #     self.current_shelf = ret_data['data']
    #     self.save
    #   else
    #     raise 'failed'
    #   end
    # rescue
    #   logger.info "InboundBatchSku[#{self.id}] get_current_shelf failed"
    # end
  end

  private
  def setup
    self.status ||= 'new'
    self.operate_infos ||= []
  end
end
