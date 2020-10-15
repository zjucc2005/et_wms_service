class CreateReturnedOrders < ActiveRecord::Migration[5.1]

  def change
    create_table :returned_orders do |t|
      t.references :outbound_order
      t.jsonb :returned_skus, :default => []
      t.bigint :operator_id
      t.string :operator

      t.timestamps :null => false
    end
  end

end
