class CreateSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :slots do |t|
      t.references :ground, null: false, foreign_key: true
      t.date :slot_date
      t.string :start_time
      t.string :end_time
      t.decimal :price
      t.string :status

      t.timestamps
    end
  end
end
