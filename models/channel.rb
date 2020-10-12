# encoding: utf-8
class Channel < ActiveRecord::Base
  has_many :accounts_and_channels, :class_name => 'AccountAndChannel', :dependent => :destroy
  has_many :accounts, :class_name => 'Account', :through => :accounts_and_channels, :source => :account
  has_many :children, :class_name => 'Channel', :foreign_key => :parent_id
  belongs_to :parent, :class_name => 'Channel'

  validates_presence_of   :name
  validates_uniqueness_of :name, :case_sensitive => false

  extend QueryFilter

  def can_delete?
    accounts.blank? && children.blank?
  end

  def to_api
    { :id => id, :name => name }
  end
end
