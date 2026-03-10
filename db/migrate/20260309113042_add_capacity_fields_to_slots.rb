class AddCapacityFieldsToSlots < ActiveRecord::Migration[8.1]
  def change
    add_column :slots, :max_teams, :integer
    add_column :slots, :teams_booked_count, :integer
  end
end
