# encoding: utf-8
class Application < ActiveRecord::Base
  has_many :roles, :class_name => 'Role', :dependent => :destroy
  validates_presence_of :name
  validates_uniqueness_of :name, :case_sensitive => false

  def can_delete?
    roles.blank?
  end
end
