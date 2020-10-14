class CreateDepots < ActiveRecord::Migration[5.1]

  def change
    create_table :depots do |t|
      t.references :account
      t.string :channel
      t.string :name
      t.string :depot_code
      t.string :country
      t.string :province
      t.string :city
      t.string :district
      t.string :street
      t.string :street_number
      t.string :house_number
      t.string :postcode
      t.string :telephone

      t.timestamps :null => false
    end
  end

end
