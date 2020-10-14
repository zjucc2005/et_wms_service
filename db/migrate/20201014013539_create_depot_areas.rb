class CreateDepotAreas < ActiveRecord::Migration[5.1]

  def change
    create_table :depot_areas do |t|
      t.references :depot
      t.string :area_code

      t.timestamps :null => false
    end
  end

end
