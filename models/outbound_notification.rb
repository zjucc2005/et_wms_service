# encoding: utf-8
class OutboundNotification < ActiveRecord::Base
  extend QueryFilter

  has_many :outbound_orders, :class_name => 'OutboundOrder', :dependent => :destroy

  validates_presence_of   :outbound_num
  validates_uniqueness_of :outbound_num
  validates_inclusion_of  :status, :in => %w[new in_process reopened closed finished]
  validates_presence_of   :created_by

  before_validation :setup, :on => :create

  # STATUS PROCESS: new => in_process/reopened <=> closed => finished

  def to_api
    to_api_simple.merge(outbound_orders: outbound_orders.map(&:to_api))
  end

  def to_api_simple
    {
      id: id,
      outbound_num:     outbound_num,
      status:           status,
      created_by:       created_by,
      allocator_id:     allocator_id,
      allocator:        allocator,
      scheduled_time:   scheduled_time,
      created_at:       created_at,
      updated_at:       updated_at,
      mp4_confirmed:    mp4_confirmed?,
      need_mp4_confirm: need_mp4_confirm?,
      outbound_orders_count: outbound_orders.count
    }
  end

  def can_delete?
    %w[new].include? status
  end

  def can_allocate?
    %w[new].include? status
  end

  def can_close?
    outbound_orders.where(status: %w[new allocated picked]).count == 0
  end

  def can_reopen?
    %w[closed].include? status
  end

  def can_finish?
    %w[closed].include? status
  end

  def mp4_confirmed?
    outbound_orders.where.not(status: %w[cancelled]).count > 0 &&
    outbound_orders.where.not(status: %w[cancelled]).where(mp4_confirmed: false).count == 0
  end

  def need_mp4_confirm?
    outbound_orders.wait_to_mp4_confirm.count > 0
  end

  def update_method(method)
    outbound_orders.each{ |order| order.update!(outbound_method: method) }
  end

  def update_status!
    return if status == 'finished'
    outbound_orders_status = outbound_orders.pluck(:status).uniq
    if outbound_orders_status.count == 1 && outbound_orders_status.include?('new')
      self.update!(status: 'new')
    else
      self.update!(status: 'in_process')
    end
  end

  private
  def setup
    self.outbound_num ||= gen_outbound_num
    self.status ||= 'new'
  end

  def gen_outbound_num
    seq = ActiveRecord::Base.connection.execute("select nextval('outbound_num_seq')")[0]['nextval']
    "OUT#{Time.now.strftime('%y%m%d')}#{sprintf('%04d', seq)}"
  end

end
