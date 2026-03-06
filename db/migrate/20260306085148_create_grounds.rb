class CreateGrounds < ActiveRecord::Migration[8.1]
  def change
    create_table :grounds do |t|
      t.string :name
      t.string :location
      t.string :sport_type
      t.decimal :price_per_hour
      t.string :opening_time
      t.string :closing_time
      t.string :image_url
      t.text :amenities

      t.timestamps
    end
  end
end
