# encoding: utf-8
class InboundSku < ActiveRecord::Base
  belongs_to :account, :class_name => 'Account'
  belongs_to :inbound_notification, :class_name => 'InboundNotification'
  has_many :inbound_received_skus, :class_name => 'InboundReceivedSku'
  has_many :inbound_batch_skus,    :class_name => 'InboundBatchSku'

  validates_presence_of :inbound_notification_id
  validates_inclusion_of :status, :in => %w[new finished]
  validates_presence_of :sku_code, :barcode, :sku_owner
  validates_presence_of :quantity
  validates_numericality_of :quantity, :greater_than => 0

  before_validation :setup,                           :on => :create
  before_validation :validate_uniqueness_of_sku_code, :on => :create

  def to_api
    {
      id: id,
      status:              status,
      sku_code:            sku_code,
      barcode:             barcode,
      name:                name,
      foreign_name:        foreign_name,
      sku_owner:           sku_owner,
      quantity:            quantity,            # 预报数量
      received_quantity:   received_quantity,   # 实收数量
      registered_quantity: registered_quantity, # 登记数量
      operated_quantity:   operated_quantity,   # 上架数量
      problem_quantity:    problem_quantity,    # 问题数量
      production_date:     production_date,
      expiry_date:         expiry_date,
      country_of_origin:   country_of_origin,
      abc_category:        abc_category,
      can_delete:          can_delete?,
      created_at:          created_at,
      updated_at:          updated_at
    }
  end

  def received_quantity
    inbound_received_skus.sum(:quantity)
  end

  def registered_quantity
    inbound_batch_skus.sum(:quantity)
  end

  def operated_quantity
    inbound_batch_skus.sum(&:operated_quantity)
  end

  def problem_quantity
    inbound_batch_skus.where.not(problem_type: nil).sum(:quantity)
  end

  def can_update?
    status == 'new' && inbound_notification.can_operate?
  end

  def can_delete?
    status == 'new' && inbound_notification.can_operate? && inbound_received_skus.blank? && inbound_batch_skus.blank?
  end

  def inventory
    Inventory.where(account_id: account_id, sku_code: sku_code, barcode: barcode).first
  end

  # 根据接口参数组装数据
  def construct_by_resource(resource)
    product = Product.joins(:account).where(
      'accounts.email'    => resource['sku_owner'].strip,
      'products.sku_code' => resource['sku_code'].strip,
      'products.barcode'  => resource['barcode'].strip
    ).first
    if product
      self.account_id = product.account_id
      self.name = product.name
      self.foreign_name = product.foreign_name
      self.sku_code = resource['sku_code']
      self.barcode = resource['barcode']
      self.quantity = resource['quantity']
      self.production_date = resource['production_date']
      self.expiry_date = resource['expiry_date']
      self.country_of_origin = resource['country_of_origin']
      self.abc_category = resource['abc_category']
      self # return
    else
      raise 'sku_code is invalid'
    end
  end

  # 验证 sku_code 是否存在 >> 调用 product 服务
  # 为了在跑测试时被忽略, 改为显式调用
  # def validate_existence_of_sku_code
  #   helper = Class.new
  #   helper.extend EtInbound::App::BaseHelper
  #   helper.extend EtInbound::App::ApiHelper
  #
  #   params   = { sku_code: sku_code, barcode: barcode, sku_owner: sku_owner }
  #   response = Api.get(helper.product_search_url, params)
  #   ret_data = JSON.parse response.body
  #   if ret_data['status'] == 'succ'
  #     self.name         = ret_data['data']['name']
  #     self.foreign_name = ret_data['data']['foreign_name']
  #   else
  #     raise 'sku_code is invalid'
  #   end
  # end

  private
  def setup
    self.status ||= 'new'
  end

  # 一个入库预报内的 sku_code 不可重复
  def validate_uniqueness_of_sku_code
    if InboundSku.where(sku_code: sku_code, inbound_notification_id: inbound_notification_id).where.not(id: id).count > 0
      errors.add(:sku_code, :taken)
    end
  end

end
