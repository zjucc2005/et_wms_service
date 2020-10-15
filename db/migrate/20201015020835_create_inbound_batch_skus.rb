class CreateInboundBatchSkus < ActiveRecord::Migration[5.1]

  def change
    create_table :inbound_batch_skus do |t|
      t.references :inbound_batch
      t.references :inbound_sku
      t.string :status
      t.integer :quantity
      t.jsonb :operate_infos
      t.datetime :production_date
      t.datetime :expiry_date
      t.string :country_of_origin
      t.string :abc_category
      t.string :problem_type
      t.string :problem_memo
      t.string :operate_memo
      t.jsonb :current_shelf, :default => []

      t.timestamps :null => false
    end
  end

end
