class CreateAccountGroups < ActiveRecord::Migration[5.1]

  def change
    create_table :account_groups do |t|
      t.string :name
      t.timestamps null: false
    end
  end

end
