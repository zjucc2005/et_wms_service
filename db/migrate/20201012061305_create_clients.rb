class CreateClients < ActiveRecord::Migration[5.1]

  def change
    create_table :clients do |t|
      t.references :account
      t.string :identifier
      t.string :secret
      t.string :name
      t.string :website
      t.string :redirect_uri

      t.timestamps :null => false
    end
  end

end
