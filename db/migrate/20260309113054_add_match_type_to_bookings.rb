class AddMatchTypeToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :match_type, :string
  end
end
