class ReplaceInterestWithPhoneOnUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :interest, :string
    add_column :users, :phone, :string
  end
end