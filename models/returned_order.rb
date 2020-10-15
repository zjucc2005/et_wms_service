# encoding: utf-8
class ReturnedOrder < ActiveRecord::Base
  extend QueryFilter

  belongs_to :outbound_order, :class_name => 'OutboundOrder'
end
