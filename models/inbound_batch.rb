# encoding: utf-8
class InboundBatch < ActiveRecord::Base
  extend QueryFilter

  belongs_to :inbound_notification, :class_name => 'InboundNotification'
  has_many :inbound_batch_skus, :class_name => 'InboundBatchSku', :dependent => :destroy

  validates_presence_of   :inbound_notification_id
  validates_presence_of   :batch_num
  validates_uniqueness_of :batch_num
  validates_inclusion_of  :status, :in => %w[new in_process finished]

  before_validation :setup, :on => :create

  def to_api
    to_api_simple.merge(inbound_batch_skus: inbound_batch_skus.map(&:to_api))
  end

  # get rid of problem skus
  def to_api_operate
    to_api_simple.merge(inbound_batch_skus: inbound_batch_skus.normal.map(&:to_api))
  end

  def to_api_simple
    {
      id: id,
      inbound_num:      inbound_notification.inbound_num,
      batch_num:        batch_num,
      status:           status,
      operator_ids:     operator_ids,
      operators:        operators,
      refer_num:        refer_num,
      registrar_email:  registrar,
      registrar_id:     registrar_id,
      created_at:       created_at,
      updated_at:       updated_at,
      only_problem_sku: only_problem_sku?
    }
  end

  # operator_ids 转换成 email 显示
  def operators
    operator_ids.map{|uid| Account.find(uid).email rescue nil }
  end

  def can_delete?
    status == 'new' and inbound_notification.can_operate?
  end

  # 创建登记批次中的sku详情
  # resource = {
  #   'barcode'           => '123456',
  #   'quantity'          => 10,
  #   'problem_type'      => '问题类型',
  #   'problem_memo'      => '问题备注',
  #   'production_date'   => '2018-10-24',
  #   'expiry_date'       => '2019-10-24',
  #   'country_of_origin' => 'CN',
  #   'abc_category'      => 'A'
  # }
  def create_inbound_batch_skus!(resource)
    # sku 存在性验证
    inbound_sku = inbound_notification.inbound_skus.where(barcode: resource['barcode']).first
    raise "barcode[#{resource['barcode']}] not found" if inbound_sku.nil?
    # sku 数量验证
    quantity = Integer(resource['quantity'])
    raise(I18n.t('api.errors.greater_than', :field => 'quantity', :value => 0)) if quantity <= 0
    ceiling = inbound_sku.received_quantity - inbound_sku.registered_quantity
    raise(I18n.t('api.errors.less_than_or_equal_to', :field => 'quantity', :value => ceiling)) if quantity > ceiling
    # 创建和返回
    inbound_batch_skus.create!(
      inbound_sku_id:    inbound_sku.id,
      quantity:          quantity,
      problem_type:      resource['problem_type'],
      problem_memo:      resource['problem_memo'],
      production_date:   resource['production_date']   || inbound_sku.production_date,
      expiry_date:       resource['expiry_date']       || inbound_sku.expiry_date,
      country_of_origin: resource['country_of_origin'] || inbound_sku.country_of_origin,
      abc_category:      resource['abc_category']      || inbound_sku.abc_category
    )
    self
  end

  def update_status!
    status_array = inbound_batch_skus.normal.pluck(:status).uniq
    if status_array.length == 0
      self.update!(status: 'new')
    elsif status_array.length == 1 and status_array.include?('new')
      self.update!(status: 'new')
    elsif status_array.length == 1 and status_array.include?('finished')
      self.update!(status: 'finished')
    else
      self.update!(status: 'in_process')
    end
  end

  def gen_inbound_batch_num
    seq = ActiveRecord::Base.connection.execute("select nextval('inbound_batch_num_seq')")[0]['nextval']
    "#{inbound_notification.inbound_num}N#{sprintf('%03d', seq)}"
  end

  # >> API
  def self.remote_inbound_operation(inbound_operation_url, resource)
    unless Padrino.env == :development
      response = Api.post(inbound_operation_url, resource)
      ret_data = JSON.parse response.body
      raise ret_data['reason'][0] unless ret_data['status'] == 'succ'
    end
  end
  # >> API

  def inventory_register
    params = {
      batch_num: self.batch_num,
      depot_code: self.inbound_notification.inbound_depot_code,
      inbound_batch_skus: self.inbound_batch_skus.normal.map(&:to_api_register)
    }
    account = Account.find(inbound_notification.created_by)
    Inventory::Operation.register_operation(params, account)
  end

  # 是否只包含问题sku
  def only_problem_sku?
    inbound_batch_skus.normal.count == 0
  end

  private
  def setup
    self.batch_num ||= gen_inbound_batch_num
    self.status = 'new'
  end

end
