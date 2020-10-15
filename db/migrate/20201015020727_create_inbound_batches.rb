class CreateInboundBatches < ActiveRecord::Migration[5.1]

  def change
    create_table :inbound_batches do |t|
      t.references :inbound_notification
      t.string :batch_num
      t.string :status
      t.jsonb :operator_ids, :default => []
      t.string :refer_num
      t.bigint :registrar_id
      t.string :registrar

      t.timestamps :null => false
    end
  end

end
