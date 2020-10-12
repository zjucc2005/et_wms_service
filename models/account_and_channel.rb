# encoding: utf-8
class AccountAndChannel < ActiveRecord::Base
  self.table_name = 'accounts_and_channels'
  belongs_to :account, :class_name => 'Account'
  belongs_to :channel, :class_name => 'Channel'
end