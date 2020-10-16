# encoding: utf-8
class OutboundOrder < ActiveRecord::Base
  extend QueryFilter

  belongs_to :outbound_notification, :class_name => 'OutboundNotification'
  has_many :outbound_skus, :class_name => 'OutboundSku', :dependent => :destroy
  has_many :returned_orders, :class_name => 'ReturnedOrder'

  validates_presence_of :outbound_notification_id, :outbound_num
  validates_presence_of :order_num
  validates_presence_of :depot_code
  validates_inclusion_of :status, :in => %w[new allocated picked printed sent oos cancelled returned]
  validates_inclusion_of :outbound_method, :in => %w[picking seeding], :allow_nil => true

  before_validation :setup, :on => :create

  scope :wait_to_mp4_confirm, lambda { where.not(parcel_num: nil, status: 'cancelled').where(mp4_confirmed: false) }

  def to_api
    to_api_simple.merge(
      {
        outbound_skus:      outbound_skus.map(&:to_api),
        shpmt_num:          shpmt_num,
        shpmt_product:      shpmt_product,
        shpmt_addr_info:    shpmt_addr_info,
        parcel_num:         parcel_num,
        weight:             weight,
        length:             length,
        width:              width,
        height:             height,
        price:              price,
        currency:           currency
      }
    )
  end

  def to_api_simple
    {
      id: id,
      created_by:         created_by,
      outbound_num:       outbound_num,
      batch_num:          batch_num,
      order_num:          order_num,
      depot_code:         depot_code,
      status:             status,
      outbound_method:    outbound_method,
      operator_id:        operator_id,
      operator:           operator,
      has_operate_infos:  has_operate_infos,
      mp4_confirmed:      mp4_confirmed,
      mp4_confirmed_at:   mp4_confirmed_at,
      created_at:         created_at,
      updated_at:         updated_at
    }
  end

  # mypost4u parcel confirmation logs
  def to_api_mp4_confirm_logs
    {
      id: id,
      outbound_num:     outbound_num,
      batch_num:        batch_num,
      order_num:        order_num,
      parcel_num:       parcel_num,
      mp4_confirmed_at: mp4_confirmed_at
    }
  end

  # returned orders
  def to_api_returned
    returned_order = returned_orders.first
    {
      id: id,
      outbound_num:       outbound_num,
      batch_num:          batch_num,
      order_num:          order_num,
      depot_code:         depot_code,
      shpmt_num:          shpmt_num,
      shpmt_product:      shpmt_product,
      status:             status,
      created_at:         created_at,
      updated_at:         updated_at,
      returned_at:        returned_at,
      returned_skus:      returned_order.try(:returned_skus) || [],
      operator:           returned_order.try(:operator),
    }
  end

  def can_allocate_method?
    outbound_method.blank? && %w[new].include?(status) && outbound_notification.status != 'finished'
  end

  def can_allocate_operator?
    outbound_method.present? && %w[new allocated].include?(status) && outbound_notification.status != 'finished'
  end

  # outbound_method => %w[picking seeding]
  def allocate_method!(outbound_method)
    self.update!(outbound_method: outbound_method)
    outbound_notification.update!(status: 'in_process') if outbound_notification.status == 'new'
  end

  def allocate_operator!(operator)
    account = Account.find_by_email(operator.try(:strip))
    self.update!(operator_id: account.id, operator: account.email, status: 'allocated')
  end

  def can_pick?
    if outbound_method == 'picking'
      %w[allocated].include?(status) && has_operate_infos
    else
      false
    end
  end

  def can_print?
    %w[picked printed].include?(status)
  end

  def can_cancel?
    %w[new allocated picked printed].include?(status) && !mp4_confirmed?
  end

  def can_return?
    %w[printed sent].include?(status)
  end

  # 是否已取货(下架) - 此时取消订单需要重新上架(调接口自动生成入库预报/批次)
  def is_picked?
    # 加入seeding方式, 需增加对应的判断, 完成wave的取货后, 也属于picked
    %w[picked printed sent].include?(status)
  end

  def cancel!
    self.update!(status: 'cancelled')
  end

  def can_mp4_confirm?
    parcel_num.present?
  end

  # mypost4u 包裹确认, 记录确认时间
  def mp4_confirm!
    self.update!(mp4_confirmed: true, mp4_confirmed_at: Time.now)
  end

  def mp4_file_path
    fold_path = "file_mp4/#{id}"
    dir_path  = "public/#{fold_path}"
    FileUtils.mkdir_p dir_path unless File.exist? dir_path
    posting_path  = "/#{fold_path}/#{batch_num}_posting.pdf"
    shipment_path = "/#{fold_path}/#{batch_num}_shipment.pdf"
    [posting_path, shipment_path]
  end

  # 批量更新运单号
  def self.batch_update_shpmt_num(resource)
    transaction do
      resource.each do |r|
        order = self.where(batch_num: r['batch_num']).first
        order.update!(shpmt_num: r['shpmt_num']) if order
      end
    end
  end

  # sku重新入库, 生成入库预报
  def create_reshelf_notification
    return false unless self.is_picked?  # 只能对已取货订单进行重新入库

    ActiveRecord::Base.transaction do
      # create InboundNotification
      @inbound_notification = InboundNotification.reshelf_notifications.create!(
        inbound_depot_code: self.depot_code,
        scheduled_time: Time.now,
        created_by: self.created_by,
        channel: self.channel,
        data_source: 'system'
      )

      self.outbound_skus.each_with_index do |outbound_sku, index|
        @inbound_notification.inbound_skus.create!(
          sku_code: outbound_sku.sku_code,
          barcode: outbound_sku.barcode,
          account_id: outbound_sku.account_id,
          quantity: outbound_sku.quantity
        )
      end

      # create InboundReceivedInfo && InboundBatch
      @inbound_received_info = @inbound_notification.inbound_received_infos.create!(data_source: 'system')
      @inbound_batch         = @inbound_notification.inbound_batches.create!(refer_num: self.batch_num)
      @inbound_notification.inbound_skus.each do |inbound_sku|
        inbound_sku.inbound_received_skus.create!(inbound_received_info_id: @inbound_received_info.id, quantity: inbound_sku.quantity)
        inbound_sku.inbound_batch_skus.create!(inbound_batch_id: @inbound_batch.id, quantity: inbound_sku.quantity)
      end

      @inbound_batch.inventory_register
    end
  end

  private
  def setup
    self.status ||= 'new'
    self.outbound_num = outbound_notification.outbound_num
    self.created_by = outbound_notification.created_by
    self.channel = outbound_notification.channel
    self.batch_num = gen_batch_num
  end

  def gen_batch_num
    max_seq = outbound_notification.outbound_orders.maximum(:seq) || 0
    self.seq = max_seq + 1
    "#{outbound_num}N#{sprintf('%03d', self.seq)}"
  end
end
