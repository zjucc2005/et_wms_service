# encoding: utf-8
class Depot < ActiveRecord::Base
  extend QueryFilter

  belongs_to :account, :class_name => 'Account'
  has_many :depot_areas, :class_name => 'DepotArea', :dependent => :destroy
  has_many :shelves, :class_name => 'Shelf', :dependent => :destroy

  validates_presence_of   :name
  validates_presence_of   :depot_code
  validates_uniqueness_of :depot_code, :case_sensitive => false
  validates_presence_of   :country, :city

  def to_api
    {
      id: id,
      account_id:    account_id,
      depot_owner:   account.email,
      channel:       channel,
      name:          name,
      depot_code:    depot_code,
      depot_areas:   depot_areas.map(&:to_api),
      country:       country,
      province:      province,
      city:          city,
      district:      district,
      street:        street,
      street_number: street_number,
      house_number:  house_number,
      postcode:      postcode,
      telephone:     telephone,
      can_delete:    can_delete?
    }
  end

  def can_delete?
    depot_areas.blank?
  end

  def has_shelf_num?(shelf_num)
    shelves.each do |shelf|
      return true if shelf.shelf_infos.where(shelf_num: shelf_num).count > 0
    end
    false
  end

end
