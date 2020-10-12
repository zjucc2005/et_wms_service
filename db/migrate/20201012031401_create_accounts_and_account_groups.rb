class CreateAccountsAndAccountGroups < ActiveRecord::Migration[5.1]

  def change
    create_table :accounts_and_account_groups do |t|
      t.references :account
      t.references :account_group

      t.timestamps null: false
    end
  end

end
