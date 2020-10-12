# encoding: utf-8
class AccountAndRole < ActiveRecord::Base
  self.table_name = 'accounts_and_roles'
  belongs_to :account, :class_name => 'Account'
  belongs_to :role,    :class_name => 'Role'
end
