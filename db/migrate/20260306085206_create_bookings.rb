class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :ground, null: false, foreign_key: true
      t.references :slot, null: false, foreign_key: true
      t.date :booking_date
      t.decimal :total_price
      t.string :status
      t.string :payment_status

      t.timestamps
    end
  end
end
