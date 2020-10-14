class CreateInventoryOperationLogs < ActiveRecord::Migration[5.1]

  def change
    create_table :inventory_operation_logs do |t|
      t.references :account
      t.string :channel
      t.references :inventory
      t.string :operation
      t.string :sku_code
      t.string :barcode
      t.string :batch_num
      t.string :shelf_num
      t.integer :quantity
      t.bigint :operator_id
      t.string :operator
      t.string :remark
      t.bigint :reference_id
      t.string :status
      t.string :refer_num

      t.timestamps :null => false
    end
  end

end
