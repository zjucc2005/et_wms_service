class CreateAccountsAndRoles < ActiveRecord::Migration[5.1]

  def change
    create_table :accounts_and_roles do |t|
      t.references :account
      t.references :role

      t.timestamps null: false
    end
  end

end
