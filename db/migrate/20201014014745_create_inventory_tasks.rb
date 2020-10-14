class CreateInventoryTasks < ActiveRecord::Migration[5.1]

  def change
    create_table :inventory_tasks do |t|
      t.references :account
      t.string :channel
      t.string :task_num
      t.string :operation
      t.string :status
      t.jsonb :operator_ids, :default => []
      t.datetime :scheduled_time

      t.timestamps :null => false
    end
  end

end
