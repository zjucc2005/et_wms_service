class CreateShelfInfos < ActiveRecord::Migration[5.1]

  def change
    create_table :shelf_infos do |t|
      t.references :shelf
      t.string :shelf_num
      t.integer :column
      t.integer :row
      t.string :spec

      t.timestamps :null => false
    end
  end

end
