class CreateProductCategories < ActiveRecord::Migration[5.1]

  def change
    create_table :product_categories do |t|
      t.string :name
      t.string :foreign_name
      t.string :hscode
      t.bigint :parent_id

      t.timestamps :null => false
    end
  end

end
