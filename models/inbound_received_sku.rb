# encoding: utf-8
class InboundReceivedSku < ActiveRecord::Base
  belongs_to :inbound_sku, :class_name => 'InboundSku'
  belongs_to :inbound_received_info, :class_name => 'InboundReceivedInfo'

  validates_numericality_of :quantity, :greater_than => 0

  def to_api
    {
      id: id,
      account_id: inbound_sku.account_id,
      sku_code:   inbound_sku.sku_code,
      barcode:    inbound_sku.barcode,
      sku_owner:  inbound_sku.account.email,
      quantity:   quantity
    }
  end
end
