class CreateInventoryTaskTransferInfos < ActiveRecord::Migration[5.1]

  def change
    create_table :inventory_task_transfer_infos do |t|
      t.references :inventory_task
      t.references :inventory
      t.string :status
      t.string :to_depot_code
      t.string :from_shelf_num
      t.string :to_shelf_num
      t.integer :transfer_quantity
      t.bigint :operator_id
      t.string :operator

      t.timestamps :null => false
    end
  end

end
