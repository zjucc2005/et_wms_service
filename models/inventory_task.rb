# encoding: utf-8
class InventoryTask < ActiveRecord::Base
  extend QueryFilter

  belongs_to :account,      :class_name => 'Account'
  has_many :transfer_infos, :class_name => 'InventoryTaskTransferInfo', :dependent => :destroy
  has_many :check_infos,    :class_name => 'InventoryTaskCheckInfo',    :dependent => :destroy
  has_one  :check_type,     :class_name => 'InventoryTaskCheckType',    :dependent => :destroy

  before_validation :setup, :on => :create

  validates_presence_of   :task_num
  validates_uniqueness_of :task_num
  validates_inclusion_of  :operation, :in => %w[transfer check]
  validates_inclusion_of  :status, :in => %w[new pending finished cancelled]
  # validates_presence_of   :sku_owner
  # validates_presence_of   :operators

  scope :transfer_tasks, lambda { where(operation: 'transfer') }
  scope :check_tasks,    lambda { where(operation: 'check') }

  def to_api
    case operation
      when 'transfer' then to_api_simple.merge(transfer_infos: transfer_infos.map(&:to_api))
      when 'check'    then to_api_simple.merge(check_infos: check_infos.map(&:to_api))
      else to_api_simple
    end
  end

  def to_api_simple
    result = {
      id: id,
      task_num: task_num,
      operation: operation,
      status: status,
      operator_ids: operator_ids,
      operators: operators,
      scheduled_time: scheduled_time,
      created_at: created_at,
      updated_at: updated_at
    }
    result.merge!(check_type: check_type.to_api) if check_type
    result
  end

  # operator_ids 转换成 email 显示
  def operators
    operator_ids.map{|uid| Account.find(uid).email rescue nil }
  end

  # only for transfer tasks, 估计没用了, 待删除
  def to_inbound_notification
    raise 'invalid operation' unless operation == 'transfer'
    {
      scheduled_time: scheduled_time,
      inbound_depot_code: transfer_infos.first.to_depot_code,
      inbound_skus: transfer_infos.map(&:to_inbound_notification)
    }
  end

  def operation_abbr
    case operation
      when 'transfer' then 'XFE'
      when 'check'    then 'CHK'
      else 'UKN'
    end
  end

  def gen_task_num
    seq = ActiveRecord::Base.connection.execute("select nextval('task_num_seq')")[0]['nextval']
    "#{operation_abbr}#{Time.now.strftime('%y%m%d')}#{sprintf('%04d', seq)}"
  end

  def update_status
    return if %w[cancelled finished].include?(status)  # 取消/完成任务后不再更新状态
    case operation
      # when 'transfer' then update_status_transfer
      when 'check'    then update_status_check
      else nil
    end
  end

  def can_update?
    %w[new pending].include?(status)
  end

  def can_cancel?
    %w[new pending].include?(status)
  end

  def cancel_inventory_task
    raise 'cannot cancel' unless can_cancel?
    case operation
      when 'transfer' then cancel_transfer
      when 'check'    then cancel_check
      else cancel_check
    end
  end

  def execute_inventory_task
    case operation
      when 'transfer' then execute_transfer_task
      when 'check'    then execute_check_task
      else nil
    end
  end

  #判断盘点任务类型并创建
  def self.get_check_task_type(account_id, channel, request_params)
    if request_params['check_type'] == 'sku'
      task = InventoryTask.create_check_task_by_sku(account_id, channel, request_params['inventory_id'], request_params['operators'])
    elsif request_params['check_type'] == 'shelf'
      task = InventoryTask.create_check_task_by_shelf_num(account_id, channel, request_params['shelf_num'],request_params['operators'])
    else
      task = nil
    end
    task
  end

  # 1. 根据 inventory_id(sku)创建盘点任务
  def self.create_check_task_by_sku(account_id, channel, inventory_id, operator_ids)
    # inv = Inventory.find(inventory_id)
    task = InventoryTask.check_tasks.create!(account_id: account_id, channel: channel, operator_ids: operator_ids)
    task.check_type = InventoryTaskCheckType.create!(inventory_id: inventory_id, check_type: 'sku')
    task
  end

  # 2. 根据 shelf_num 创建盘点任务
  def self.create_check_task_by_shelf_num(account_id, channel, shelf_num, operator_ids)
    task = InventoryTask.check_tasks.create!(account_id: account_id, channel: channel, operator_ids: operator_ids)
    # validate presence of shelf_num
    raise 'shelf_num not found' if ShelfInfo.where('shelf_num ~ ?', shelf_num.gsub('*', '.*')).blank?
    task.check_type = InventoryTaskCheckType.create!(shelf_num: shelf_num, check_type: 'shelf')
    task
  end

  # Batch processing, cron
  # BEGIN >>
  def self.generate_periodic_check_tasks
    InventorySetting.periodic_check_task_switch.where(field_value: 'on').each do |setting|
      generate_periodic_check_task(setting.account_id)
    end
  end

  def self.generate_periodic_check_task(account_id)
    personal_settings = InventorySetting.personal_settings(account_id)
    check_task_generation_interval = personal_settings['check_task_generation_interval']
    if Time.now.yday % check_task_generation_interval == 0
      logger.info "InventoryTask.generate_periodic_check_task start, #{account_id}"
      begin
        transaction do
          inventory_task = InventoryTask.check_tasks.create!(sku_owner: account_id)
          Inventory.auto_create_check_task(inventory_task.id, account_id)
          # inventories = Inventory.where(sku_owner: account)
          # inventories.map{|inventory| inventory.auto_create_check_task(inventory_task.id)}
          raise 'no check task' if inventory_task.check_infos.blank?  # rollback
          logger.info "InventoryTask.generate_periodic_check_task success, #{account_id}"
        end
      rescue Exception => e
        logger.info "InventoryTask.generate_periodic_check_task failure, #{account_id}, reason: #{e.message}"
      end
    end
  end
  # >> END

  private
  def setup
    self.task_num = gen_task_num
    self.status = 'new'
  end

  # def update_status_transfer
  #   transfer_infos.pluck(:status).include?('new') ?
  #     self.update(status: 'new') :
  #     self.update(status: 'finished')
  # end

  def update_status_check
    check_infos.pluck(:status).include?('finished') ?
      self.update(status: 'pending') :
      self.update(status: 'new')
  end

  def execute_transfer_task
    transaction do
      self.update!(status: 'finished')
      transfer_infos.map(&:execute_transfer_task)
    end
  end

  def execute_check_task
    transaction do
      self.update!(status: 'finished')
      check_infos.map(&:execute_check_task)
    end
  end

  # update && unfreeze
  def cancel_transfer
    transaction do
      self.update!(status: 'cancelled')
      self.transfer_infos.map(&:cancel_transfer_task)
    end
  end

  # update only
  def cancel_check
    transaction do
      self.update!(status: 'cancelled')
      self.check_infos.map(&:cancel_check_task)
    end
  end

end
