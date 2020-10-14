# encoding: utf-8
class InventorySetting < ActiveRecord::Base
  # System default settings >>
  module DEFAULT
    GLOBAL_CAUTION_THRESHOLD       = 0
    PERIODIC_CHECK_TASK_SWITCH     = 'off'
    CHECK_FREQUENCY_YEARLY         = 52
    CHECK_TASK_GENERATION_INTERVAL = 7
  end

  FIELD_ATTRIBUTES = {
    :global_caution_threshold       => DEFAULT::GLOBAL_CAUTION_THRESHOLD,        # 全局余量预警阈值
    :periodic_check_task_switch     => DEFAULT::PERIODIC_CHECK_TASK_SWITCH,      # 周期盘点任务开关
    :check_task_generation_interval => DEFAULT::CHECK_TASK_GENERATION_INTERVAL,  # 盘点任务自动生成间隔(单位: 天)
    :check_frequency_yearly_default => DEFAULT::CHECK_FREQUENCY_YEARLY,          # 年度计划盘点次数(默认)
    :check_frequency_yearly_cat_a   => DEFAULT::CHECK_FREQUENCY_YEARLY,          # 年度计划盘点次数(A类)
    :check_frequency_yearly_cat_b   => DEFAULT::CHECK_FREQUENCY_YEARLY,          # 年度计划盘点次数(B类)
    :check_frequency_yearly_cat_c   => DEFAULT::CHECK_FREQUENCY_YEARLY,          # 年度计划盘点次数(C类)
  }.stringify_keys

  belongs_to :account, :class_name => 'Account'

  validates_inclusion_of    :field_key,   :in => FIELD_ATTRIBUTES.keys
  validates_presence_of     :field_value
  validates_numericality_of :field_value, :greater_than_or_equal_to => 0, :only_integer => true, :if => :field_value_should_be_integer
  validates_inclusion_of    :field_value, :in => %w[on off], :if => :field_value_should_be_switch

  FIELD_ATTRIBUTES.keys.each{ |field_key| scope :"#{field_key}", lambda { where(field_key: field_key) } }

  # Friendly hash of personal settings
  def self.personal_settings(account_id)
    FIELD_ATTRIBUTES.merge Hash[where(account_id: account_id).map(&:to_api)]
  end

  def to_api
    [field_key, field_value_should_be_integer ? field_value.to_i : field_value ]
  end

  private
  def field_value_should_be_integer
    %w[
      global_caution_threshold
      check_frequency_yearly_default
      check_frequency_yearly_cat_a
      check_frequency_yearly_cat_b
      check_frequency_yearly_cat_c
      check_task_generation_interval
    ].include? field_key
  end

  def field_value_should_be_switch
    %w[
      periodic_check_task_switch
    ].include? field_key
  end

end
