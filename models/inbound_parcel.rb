# encoding: utf-8
class InboundParcel < ActiveRecord::Base
  extend QueryFilter

  belongs_to :inbound_notification, :class_name => 'InboundNotification'

  validates_presence_of  :parcel_num
  validates_inclusion_of :status, :in => %w[notified received on_shelf sent]

  before_validation :setup, :on => :create

  def to_api
    {
      id: id,
      parcel_num: parcel_num,
      status:     status,
      space_num:  space_num,
      operator_id: operator_id,
      operator:   operator,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private
  def setup
    self.status ||= 'notified'
  end

end
