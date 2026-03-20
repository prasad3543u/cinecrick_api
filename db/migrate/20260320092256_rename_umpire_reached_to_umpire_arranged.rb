# db/migrate/20260320_rename_umpire_reached_to_umpire_arranged.rb
class RenameUmpireReachedToUmpireArranged < ActiveRecord::Migration[8.1]
  def change
    rename_column :bookings, :umpire_reached, :umpire_arranged
  end
end