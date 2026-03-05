class AddDobAndInterestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :dob, :date
    add_column :users, :interest, :string
  end
end
