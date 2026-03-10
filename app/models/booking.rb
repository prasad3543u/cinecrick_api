class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :ground
  belongs_to :slot

  validates :booking_date, :total_price, :status, presence: true
end