# encoding: utf-8
class DepotArea < ActiveRecord::Base
  belongs_to :depot, :class_name => 'Depot'
  has_many :shelves, :class_name => 'Shelf', :dependent => :destroy
  validates_presence_of :area_code

  def to_api
    { id: id, area_code: area_code, can_delete: can_delete? }
  end

  def can_delete?
    shelves.blank?
  end
end
