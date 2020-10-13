class CreateServiceCategories < ActiveRecord::Migration[5.1]

  def change
    create_table :service_categories do |t|
      t.string :name
      t.string :foreign_name
      t.bigint :parent_id

      t.timestamps :null => false
    end
  end

end
