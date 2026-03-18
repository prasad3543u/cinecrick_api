class User < ApplicationRecord
  has_secure_password

  has_many :bookings, dependent: :destroy

  # Add strong validations
  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :email, presence: true, 
                    uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, format: { with: /\A\+?\d{10,15}\z/, allow_blank: true }
  validates :password, length: { minimum: 6 }, if: :password_digest_changed?
  validate :dob_must_be_valid_date

  private

  def dob_must_be_valid_date
    return if dob.blank?
    if dob > Date.today
      errors.add(:dob, "can't be in the future")
    elsif dob < 100.years.ago
      errors.add(:dob, "is too far in the past")
    end
  end
end