class CreateAccountGroupsAndRoles < ActiveRecord::Migration[5.1]

  def change
    create_table :account_groups_and_roles do |t|
      t.references :account_group
      t.references :role

      t.timestamps null: false
    end
  end

end
