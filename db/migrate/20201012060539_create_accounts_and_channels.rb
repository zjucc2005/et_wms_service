class CreateAccountsAndChannels < ActiveRecord::Migration[5.1]

  def change
    create_table :accounts_and_channels do |t|
      t.references :account
      t.references :channel

      t.timestamp null: false
    end
  end

end
