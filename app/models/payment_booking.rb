class PaymentBooking < ApplicationRecord
  belongs_to :booking

  validates :amount, :status, presence: true
  validates :status, inclusion: { in: ["paid", "pending", "partial"] }
end