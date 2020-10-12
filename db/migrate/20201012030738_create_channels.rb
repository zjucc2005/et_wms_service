class CreateChannels < ActiveRecord::Migration[5.1]

  def change
    create_table :channels do |t|
      t.string :name
      t.integer :parent_id
      t.timestamps null: false
    end
  end

end
