class AddPersonalInfosToAccounts < ActiveRecord::Migration[5.1]

  def change
    add_column :accounts, :firstname,   :string
    add_column :accounts, :lastname,    :string
    add_column :accounts, :sex,         :string
    add_column :accounts, :country,     :string
    add_column :accounts, :city,        :string
    add_column :accounts, :address,     :string
    add_column :accounts, :company,     :string
    add_column :accounts, :qq_num,      :string
    add_column :accounts, :wechat_num,  :string
    add_column :accounts, :extra_email, :string
    add_column :accounts, :memo,        :string
    add_column :accounts, :mp4_id,      :bigint
  end

end
