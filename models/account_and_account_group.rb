class AccountAndAccountGroup < ActiveRecord::Base
    self.table_name = 'accounts_and_account_groups'
    belongs_to :account, :class_name => 'Account'
    belongs_to :account_group, :class_name => 'AccountGroup'
end
