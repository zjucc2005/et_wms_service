class CreateRoles < ActiveRecord::Migration[5.1]

  def change
    create_table :roles do |t|
      t.string :name
      t.string :name_zh_cn
      t.string :description
      t.references :application
      t.timestamps null: false
    end
  end

end
