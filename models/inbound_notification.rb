# encoding: utf-8
class InboundNotification < ActiveRecord::Base
  extend QueryFilter

  has_many :inbound_skus,           :class_name => 'InboundSku',          :dependent => :destroy
  has_many :inbound_received_infos, :class_name => 'InboundReceivedInfo', :dependent => :destroy
  has_many :inbound_batches,        :class_name => 'InboundBatch',        :dependent => :destroy
  has_many :inbound_parcels,        :class_name => 'InboundParcel',       :dependent => :destroy

  validates_presence_of   :inbound_num
  validates_uniqueness_of :inbound_num
  validates_inclusion_of  :inbound_type, :in => %w[general reshelf transfer parcel]
  validates_inclusion_of  :status,       :in => %w[new in_process reopened closed finished]
  validates_presence_of   :inbound_depot_code, :created_by, :scheduled_time

  before_validation :setup, :on => :create

  scope :general_notifications,  lambda { where(inbound_type: 'general') }
  scope :reshelf_notifications,  lambda { where(inbound_type: 'reshelf') }
  scope :transfer_notifications, lambda { where(inbound_type: 'transfer')}

  # default category of transport_method
  TRANSPORT_METHOD = {
    :'self-delivery' => '货主自送',
    :express         => '快递运输',
    :truck           => '卡车运输',
    :pickup          => '上门取货'
  }.stringify_keys

  def to_api
    case inbound_type
      when 'general'  then to_api_simple.merge(inbound_skus:inbound_skus.order(:created_at => :desc).map(&:to_api))
      when 'reshelf'  then to_api_simple.merge(inbound_skus:inbound_skus.order(:created_at => :desc).map(&:to_api))
      when 'transfer' then to_api_simple.merge(inbound_skus:inbound_skus.order(:created_at => :desc).map(&:to_api))
      when 'parcel'   then to_api_simple.merge(inbound_skus:inbound_parcels.order(:created_at => :desc).map(&:to_api))
      else to_api_simple
    end
  end

  def to_api_simple
    {
      id: id,
      inbound_num:        inbound_num,
      inbound_type:       inbound_type,
      status:             status,
      inbound_depot_code: inbound_depot_code,
      created_by:         created_by,
      channel:            channel,
      data_source:        data_source,
      scheduled_time:     scheduled_time,
      created_at:         created_at,
      updated_at:         updated_at,
      can_delete:         can_delete?,
      transport_method:   transport_method,
      transport_memo:     transport_memo,
      parcel_quantity:    parcel_quantity
    }
  end

  # 能否对入库预报进行收货/登记相关操作
  def valid_inbound_type?
    %w[general transfer].include? inbound_type
  end

  def can_operate?
    %w[new in_process reopened].include? status
  end

  def can_finish?
    status == 'closed'
  end

  def can_close?
    can_operate?
  end

  def can_reopen?
    status == 'closed'
  end

  def can_delete?
    status == 'new' && inbound_received_infos.blank? && inbound_batches.blank?
  end
  alias :can_cancel? :can_delete?

  # 外层事务
  def finish!
    self.update!(status: 'finished')
    inbound_skus.each{ |inbound_sku| inbound_sku.update!(status: 'finished') }
  end

  # 转移任务取消 remote
  def cancel_transfer_task
    logger.info "remote cancel transfer task start, [#{inbound_num}]"
    @inventory_task = InventoryTask.transfer_tasks.where(task_num: inbound_num).first
    raise "task_num #{inbound_num} not found" if @inventory_task.nil?
    raise t('api.errors.cannot_update', :model => 'InventoryTask', :id => @inventory_task.id) unless @inventory_task.can_update?
    @inventory_task.cancel_inventory_task
  end

  # 转移任务完成 remote
  def finish_transfer_task
    logger.info "remote finish transfer task start, [#{inbound_num}]"
    @inventory_task = InventoryTask.transfer_tasks.where(task_num: inbound_num).first
    raise "task_num #{inbound_num} not found" if @inventory_task.nil?
    raise t('api.errors.cannot_update', :model => 'InventoryTask', :id => @inventory_task.id) unless @inventory_task.can_update?
    @inventory_task.execute_inventory_task
  end



  private
  def setup
    self.inbound_num ||= gen_inbound_num
    self.status ||= 'new'
  end

  def gen_inbound_num
    seq = ActiveRecord::Base.connection.execute("select nextval('inbound_num_seq')")[0]['nextval']
    "IN#{Time.now.strftime('%y%m%d')}#{sprintf('%04d', seq)}"
  end

end
