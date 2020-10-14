class CreateInventorySettings < ActiveRecord::Migration[5.1]

  def change
    create_table :inventory_settings do |t|
      t.references :account
      t.string :field_key
      t.string :field_value

      t.timestamps :null => false
    end
  end

end
