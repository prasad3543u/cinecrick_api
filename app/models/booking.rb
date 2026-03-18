class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :ground
  belongs_to :slot

  validates :booking_date, :total_price, :status, presence: true
  
  # Add validation to prevent duplicate bookings
  validate :user_cannot_book_same_slot_twice, on: :create
  validate :slot_must_be_available, on: :create

  private

  def user_cannot_book_same_slot_twice
    if Booking.exists?(user_id: user_id, slot_id: slot_id, status: ['pending', 'confirmed'])
      errors.add(:base, "You already have a booking for this slot")
    end
  end

  def slot_must_be_available
    slot = Slot.find_by(id: slot_id)
    if slot && (slot.status == 'booked' || slot.status == 'pending')
      errors.add(:base, "This slot is no longer available")
    end
  end
end