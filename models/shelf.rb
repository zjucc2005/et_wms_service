# encoding: utf-8
class Shelf < ActiveRecord::Base
  extend QueryFilter

  belongs_to :depot, :class_name => 'Depot'
  belongs_to :depot_area, :class_name => 'DepotArea'
  has_many :shelf_infos, :class_name => 'ShelfInfo', :dependent => :destroy

  before_validation :setup, :on => :create

  validates_presence_of     :depot_code
  validates_presence_of     :area_code
  validates_presence_of     :spec
  validates_presence_of     :seq
  validates_numericality_of :seq, :greater_than => 0
  validates_presence_of     :column_number
  validates_numericality_of :column_number, :greater_than => 0
  validates_presence_of     :row_number
  validates_numericality_of :row_number, :greater_than => 0

  after_create :create_shelf_infos
  after_update :recreate_shelf_infos

  def to_api
    {
      id: id,
      depot_id:      depot_id,
      depot_area_id: depot_area_id,
      depot_code:    depot_code,
      area_code:     area_code,
      seq:           seq,
      column_number: column_number,
      row_number:    row_number,
      spec:          spec,
      can_delete:    can_delete?
    }
  end

  def create_shelf_infos
    ActiveRecord::Base.transaction do
      1.upto(column_number) do |column|
        1.upto(row_number) do |row|
          shelf_infos.create!(column: column, row: row, spec: spec)
        end
      end
    end
  end

  def recreate_shelf_infos
    shelf_infos.delete_all if shelf_infos.count > 0
    create_shelf_infos
  end

  def can_delete?
    shelf_infos.map(&:can_delete?).exclude?(false)
  end

  private
  def setup
    self.depot_code = self.depot.depot_code
    self.area_code  = self.depot_area.area_code
    self.seq        = (self.depot_area.shelves.maximum(:seq) || 0) + 1
  end
end
