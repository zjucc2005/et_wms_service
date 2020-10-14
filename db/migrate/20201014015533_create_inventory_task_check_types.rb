class CreateInventoryTaskCheckTypes < ActiveRecord::Migration[5.1]

  def change
    create_table :inventory_task_check_types do |t|
      t.references :inventory_task
      t.references :inventory
      t.string     :check_type
      t.string     :shelf_num
    end
  end

end
