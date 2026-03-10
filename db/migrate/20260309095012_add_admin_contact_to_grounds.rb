class AddAdminContactToGrounds < ActiveRecord::Migration[8.1]
  def change
    add_column :grounds, :admin_name, :string
    add_column :grounds, :admin_phone, :string
  end
end
