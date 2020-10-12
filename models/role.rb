# encoding: utf-8
class Role < ActiveRecord::Base
  belongs_to :application, :class_name => 'Application'
  has_many :accounts_and_roles, :class_name => 'AccountAndRole', :dependent => :destroy
  has_many :accounts, :class_name => 'Account', :through => :accounts_and_roles, :source => :account
  has_many :account_groups_and_roles, :class_name => 'AccountGroupAndRole', :dependent => :destroy
  has_many :account_groups, :class_name => 'AccountGroup', :through => :account_groups_and_roles, :source => :account_group

  validates_presence_of :name, :name_zh_cn
  validates_uniqueness_of :name, :case_sensitive => false

  extend QueryFilter

  def can_delete?
    accounts.blank? && account_groups.blank?
  end

  def to_api
    { :id => id, :name => name, :name_zh_cn => name_zh_cn, :description => description,
      :application_name => application.try(:name) }
  end

  def to_api_simple
    { id: id, name: name, name_zh_cn: name_zh_cn }
  end
end
