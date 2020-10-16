class CreateInboundReceivedInfos < ActiveRecord::Migration[5.1]

  def change
    create_table :inbound_received_infos do |t|
      t.references :inbound_notification
      t.bigint :data_source
      t.bigint :receiver_id
      t.string :receiver

      t.timestamps :null => false
    end
  end

end
