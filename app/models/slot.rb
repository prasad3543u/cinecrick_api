class Slot < ApplicationRecord
  belongs_to :ground
  has_many :bookings, dependent: :destroy

  validates :slot_date, :start_time, :end_time, :price, :status, presence: true
  validates :max_teams, numericality: { greater_than: 0 }, allow_nil: true
  validates :teams_booked_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Add validation: start_time must be before end_time
  validate :start_time_before_end_time
  
  # Add validation: no overlapping slots for same ground on same date
  validate :no_overlapping_slots, on: :create

  private

  def start_time_before_end_time
    return if start_time.blank? || end_time.blank?
    if start_time >= end_time
      errors.add(:end_time, "must be after start time")
    end
  end

  def no_overlapping_slots
    return if start_time.blank? || end_time.blank? || slot_date.blank? || ground_id.blank?
    
    overlapping = Slot.where(ground_id: ground_id, slot_date: slot_date)
                      .where("start_time < ? AND end_time > ?", end_time, start_time)
                      .exists?
    
    if overlapping
      errors.add(:base, "This time slot overlaps with an existing slot")
    end
  end
end