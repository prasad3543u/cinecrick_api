class Slot < ApplicationRecord
  belongs_to :ground
  has_one :booking, dependent: :destroy

  validates :slot_date, :start_time, :end_time, :price, :status, presence: true
end