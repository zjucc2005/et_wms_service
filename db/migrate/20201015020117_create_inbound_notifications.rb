class CreateInboundNotifications < ActiveRecord::Migration[5.1]

  def change
    create_table :inbound_notifications do |t|
      t.string :inbound_num
      t.string :inbound_type
      t.string :status
      t.string :inbound_depot_code
      t.bigint :created_by
      t.string :channel
      t.string :data_source
      t.datetime :scheduled_time
      t.string :transport_method
      t.string :transport_memo
      t.integer :parcel_quantity

      t.timestamps :null => false
    end
  end

end
