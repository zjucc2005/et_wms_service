class CreateAuthorizationCodes < ActiveRecord::Migration[5.1]

  def change
    create_table :authorization_codes do |t|
      t.references :account
      t.references :client
      t.string :token
      t.string :redirect_uri
      t.datetime :expires_at

      t.timestamps :null => false
    end
  end

end
