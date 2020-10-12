class CreateAccessTokens < ActiveRecord::Migration[5.1]

  def change
    create_table :access_tokens do |t|
      t.references :account
      t.references :client
      t.references :refresh_token
      t.string :token
      t.datetime :expires_at

      t.timestamps null: false
    end
  end

end
