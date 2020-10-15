class CreateOutboundNotifications < ActiveRecord::Migration[5.1]

  def change
    create_table :outbound_notifications do |t|
      t.string :outbound_num
      t.string :status
      t.bigint :created_by
      t.string :channel
      t.string :data_source
      t.bigint :allocator_id
      t.string :allocator
      t.datetime :scheduled_time

      t.timestamps :null => false
    end
  end

end
