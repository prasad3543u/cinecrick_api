class CreateStaffPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_payments do |t|
      t.references :booking, null: false, foreign_key: true
      t.string :staff_type
      t.string :name
      t.decimal :amount
      t.string :status
      t.date :paid_date

      t.timestamps
    end
  end
end
