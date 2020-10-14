# encoding: utf-8
class ShelfInfo < ActiveRecord::Base
  belongs_to :shelf, :class_name => 'Shelf'

  before_validation :setup, :on => :create

  validates_presence_of     :shelf_num
  validates_presence_of     :spec
  validates_presence_of     :column
  validates_numericality_of :column, :greater_than => 0
  validates_presence_of     :row
  validates_numericality_of :row, :greater_than => 0

  def to_api
    {
      id: id,
      shelf_id:  shelf_id,
      shelf_num: shelf_num,
      column:    column,
      row:       row,
      spec:      spec
    }
  end

  # shelf_num's format: DepotCode + AreaCode + ShelfSeq + Column + Row
  # e.g. BC-A-01-01-01
  def gen_shelf_num
    depot_code = shelf.depot_code
    area_code  = shelf.area_code
    shelf_seq  = sprintf('%02d', shelf.seq)
    column_f   = sprintf('%02d', column)
    row_f      = sprintf('%02d', row)
    "#{depot_code}-#{area_code}-#{shelf_seq}-#{column_f}-#{row_f}"
  end

  def inventory_infos
    InventoryInfo.where(shelf_num: shelf_num, account_id: shelf.depot.account_id)
  end

  def can_delete?
    inventory_infos.count.zero?
  end

  private
  def setup
    self.shelf_num = gen_shelf_num
  end

end
