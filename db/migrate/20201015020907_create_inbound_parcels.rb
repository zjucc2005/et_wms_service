class CreateInboundParcels < ActiveRecord::Migration[5.1]

  def change
    create_table :inbound_parcels do |t|
      t.references :inbound_notification
      t.string :parcel_num
      t.string :status
      t.string :space_num
      t.bigint :operator_id
      t.string :operator

      t.timestamps :null => false
    end
  end

end
