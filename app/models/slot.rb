class Slot < ApplicationRecord
  belongs_to :ground
  has_many :bookings, dependent: :destroy

  validates :slot_date, :start_time, :end_time, :price, :status, presence: true
  validates :max_teams, numericality: { greater_than: 0 }, allow_nil: true
  validates :teams_booked_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end