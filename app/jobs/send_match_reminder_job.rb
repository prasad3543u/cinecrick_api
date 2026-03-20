class SendMatchReminderJob < ApplicationJob
  queue_as :default
  
  def perform
    tomorrow = Date.tomorrow
    
    bookings = Booking.includes(:ground, :slot, :user)
                      .where(booking_date: tomorrow, status: "confirmed")
    
    bookings.each do |booking|
      next unless booking.ground.admin_phone.present?
      
      admin_number = booking.ground.admin_phone.gsub(/\D/, '')
      message = build_admin_reminder(booking)
      
      Rails.logger.info "WhatsApp Reminder to #{admin_number}: #{message}"
    end
  end
  
  private
  
  def build_admin_reminder(booking)
    <<~MSG
      *MATCH REMINDER - TOMORROW*

      Ground: #{booking.ground.name}
      Date: #{booking.booking_date}
      Time: #{booking.slot.start_time} - #{booking.slot.end_time}

      Team: #{booking.user.name}
      Contact: #{booking.user.phone}
      Match Type: #{booking.match_type == "with_opponents" ? "With Opponents" : "Full Ground"}

      Status Checklist:
      Umpire Arranged: #{booking.umpire_arranged ? "Yes" : "No"}
      Water Arranged: #{booking.water_arranged ? "Yes" : "No"}
      Balls Ready: #{booking.balls_ready ? "Yes" : "No"}
      Ground Ready: #{booking.ground_ready ? "Yes" : "No"}

      Please ensure all arrangements are complete.

      — CrickOps Admin Alert
    MSG
  end
end