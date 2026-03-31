class CreatePaymentBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_bookings do |t|
      t.references :booking, null: false, foreign_key: true
      t.decimal :amount
      t.string :status
      t.date :payment_date
      t.text :notes

      t.timestamps
    end
  end
end
