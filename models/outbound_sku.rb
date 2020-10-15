# encoding: utf-8
class OutboundSku < ActiveRecord::Base
  extend QueryFilter

  belongs_to :account, :class_name => 'Account'
  belongs_to :outbound_order, :class_name => 'OutboundOrder'

  validates_presence_of :sku_code, :barcode, :sku_owner
  validates_numericality_of :quantity, :greater_than => 0

  before_validation :setup, :on => :create

  def to_api
    {
      id: id,
      account_id:    account_id,
      sku_code:      sku_code,
      barcode:       barcode,
      sku_owner:     account.email,
      name:          name,
      foreign_name:  foreign_name,
      quantity:      quantity,
      operate_infos: operate_infos
    }
  end

  def to_api_simple
    {
      account_id: account_id,
      sku_code:  sku_code,
      barcode:   barcode,
      sku_owner: account.email,
      quantity:  quantity,
      operate_infos: operate_infos
    }
  end

  def to_api_reshelf
    {
      account_id: account_id,
      sku_code:  sku_code,
      barcode:   barcode,
      sku_owner: account.email,
      quantity:  quantity
    }
  end

  #通过sku barcode 查询 cm_product 详情
  # def search_product_detail
  #   helper = Class.new
  #   helper.extend EtOutbound::App::BaseHelper
  #   helper.extend EtOutbound::App::ApiHelper
  #
  #   params   = { sku_code: sku_code, barcode: barcode,sku_owner:sku_owner}
  #   response = Api.get(helper.product_detail_search_url, params)
  #   ret_data = JSON.parse response.body
  #   if ret_data['status'] == 'succ'
  #     raise 'product_sales_property is null' if ret_data['data']['product_sales_property'].blank?
  #     return ret_data['data']['product_sales_property']
  #   else
  #     raise "sku_code:#{sku_code} is invalid"
  #   end
  # end

  def self.unpicked_quantity_sum(sku_code, barcode, account_id)
    self.query_filter(sku_code: sku_code, barcode: barcode, account_id: account_id, outbound_order: { status_in: %w[new allocated] }).sum(:quantity)
  end

  private
  def setup
    self.depot_code ||= outbound_order.depot_code
    self.account_id ||= outbound_order.created_by
  end

end
