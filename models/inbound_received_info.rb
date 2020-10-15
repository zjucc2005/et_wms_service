# encoding: utf-8
class InboundReceivedInfo < ActiveRecord::Base
  belongs_to :inbound_notification, :class_name => 'InboundNotification'
  has_many :inbound_received_skus, :class_name => 'InboundReceivedSku', :dependent => :destroy

  validates_presence_of :inbound_notification_id

  def to_api
    {
      id: id,
      inbound_num:           inbound_notification.inbound_num,
      created_at:            created_at,
      created_by:            created_by,
      receiver_email:        receiver,
      receiver_id:           receiver_id,
      inbound_received_skus: inbound_received_skus.map(&:to_api),
      can_delete:            can_delete?
    }
  end

  # 没有登记批次时, 可以删除收货信息
  def can_delete?
    inbound_notification.inbound_batches.count == 0 rescue false
  end

  # 创建收货记录中的sku详情
  # resource = { 'barcode' => '123456', 'quantity' => 10 }
  def create_inbound_received_skus!(resource)
    # sku 存在性验证
    inbound_sku = inbound_notification.inbound_skus.where(barcode: resource['barcode']).first
    raise "barcode[#{resource['barcode']}] not found" if inbound_sku.nil?
    # sku 数量验证
    quantity = Integer(resource['quantity'])
    raise(I18n.t('api.errors.greater_than', :field => 'quantity', :value => 0)) if quantity <= 0
    # 创建和返回
    inbound_received_skus.create!(inbound_sku_id: inbound_sku.id, quantity: quantity)
    self
  end

end
