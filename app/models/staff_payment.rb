
class StaffPayment < ApplicationRecord
  belongs_to :booking

  validates :staff_type, :name, :amount, :status, presence: true
  validates :staff_type, inclusion: { in: ["umpire", "groundsman"] }
  validates :status, inclusion: { in: ["paid", "pending"] }
end