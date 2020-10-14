class CreateInventoryTaskCheckInfos < ActiveRecord::Migration[5.1]

  def change
    create_table :inventory_task_check_infos do |t|
      t.references :inventory_task
      t.references :inventory
      t.string :status
      t.string :shelf_num
      t.integer :check_quantity
      t.bigint :operator_id
      t.string :operator

      t.timestamps :null => false
    end
  end

end
