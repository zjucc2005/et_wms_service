class CreateShelves < ActiveRecord::Migration[5.1]

  def change
    create_table :shelves do |t|
      t.references :depot
      t.references :depot_area
      t.string :depot_code
      t.string :area_code
      t.integer :seq
      t.integer :column_number
      t.integer :row_number
      t.string :spec

      t.timestamps :null => false
    end
  end

end
