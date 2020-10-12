class CreateAccounts < ActiveRecord::Migration[5.1]

  def change
    create_table :accounts do |t|
      t.string :email
      t.string :nickname
      t.string :telephone
      t.string :password_digest
      t.string :confirmation_digest
      t.datetime :confirmed_at
      t.string :reset_password_digest
      t.datetime :reset_password_sent_at
      t.string :remember_digest
      t.datetime :remember_created_at
      t.boolean :is_valid
      t.integer :parent_id

      t.timestamps null: false
    end
  end

end
