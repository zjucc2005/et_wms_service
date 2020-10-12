class AccountGroupAndRole < ActiveRecord::Base
    self.table_name = 'account_groups_and_roles'
    belongs_to :account_group, :class_name => 'AccountGroup'
    belongs_to :role, :class_name => 'Role'
end