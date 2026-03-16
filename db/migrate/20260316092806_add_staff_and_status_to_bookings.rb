class AddStaffAndStatusToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :umpire_name,      :string
    add_column :bookings, :umpire_phone,     :string
    add_column :bookings, :groundsman_name,  :string
    add_column :bookings, :groundsman_phone, :string
    add_column :bookings, :umpire_reached,   :boolean, default: false
    add_column :bookings, :water_arranged,   :boolean, default: false
    add_column :bookings, :balls_ready,      :boolean, default: false
    add_column :bookings, :ground_ready,     :boolean, default: false
  end
end