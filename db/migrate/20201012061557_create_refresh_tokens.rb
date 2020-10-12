class CreateRefreshTokens < ActiveRecord::Migration[5.1]

  def change
    create_table :refresh_tokens do |t|
      t.references :account
      t.references :client
      t.string :token
      t.datetime :expires_at

      t.timestamps :null => false
    end
  end

end
