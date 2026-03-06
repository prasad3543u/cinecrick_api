class Ground < ApplicationRecord
  has_many :slots, dependent: :destroy
  has_many :bookings, dependent: :destroy

  validates :name, :location, :sport_type, :price_per_hour, presence: true
end