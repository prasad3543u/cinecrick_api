class AddReminderTrackingToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :reminder_sent, :boolean, default: false
    add_column :bookings, :reminder_sent_at, :datetime
  end
end