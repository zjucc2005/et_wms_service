class CreateOutboundOrders < ActiveRecord::Migration[5.1]

  def change
    create_table :outbound_orders do |t|
      t.references :outbound_notification
      t.bigint :created_by
      t.string :channel
      t.string :outbound_num
      t.string :batch_num
      t.integer :seq
      t.string :order_num
      t.string :depot_code
      t.string :status
      t.string :outbound_method
      t.bigint :operator_id
      t.string :operator
      t.string :shpmt_num
      t.string :shpmt_product
      t.jsonb  :shpmt_addr_info
      t.string :parcel_num
      t.boolean :has_operate_infos, :default => false
      t.decimal :weight, :precision => 10, :scale => 2
      t.decimal :length, :precision => 10, :scale => 2
      t.decimal :width,  :precision => 10, :scale => 2
      t.decimal :height, :precision => 10, :scale => 2
      t.decimal :price,  :precision => 10, :scale => 2
      t.string :currency
      t.boolean :mp4_confirmed, :default => false
      t.datetime :mp4_confirmed_at
      t.datetime :sent_at
      t.datetime :printed_at
      t.datetime :returned_at

      t.timestamps :null => false
    end
  end

end
