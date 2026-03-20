class AutoReminderService
  # Send reminders for matches starting in 12 hours
  def self.send_reminders
    now = Time.current
    target_time = now + 12.hours
    
    # Find matches where match time is within the next hour window
    reminder_window_start = target_time - 30.minutes
    reminder_window_end = target_time + 30.minutes
    
    bookings = Booking.includes(:ground, :slot, :user)
                      .where(status: "confirmed")
                      .where(reminder_sent: false)
                      .where("booking_date = ? AND start_time >= ? AND start_time <= ?", 
                             target_time.to_date,
                             reminder_window_start.strftime("%H:%M"),
                             reminder_window_end.strftime("%H:%M"))
    
    sent_count = { admin: 0, user: 0 }
    
    bookings.each do |booking|
      # Send to Ground Admin
      if booking.ground.admin_phone.present?
        admin_number = booking.ground.admin_phone.gsub(/\D/, '')
        admin_message = build_admin_message(booking)
        send_whatsapp(admin_number, admin_message)
        sent_count[:admin] += 1
      end
      
      # Send to User (Team)
      if booking.user.phone.present?
        user_number = booking.user.phone.gsub(/\D/, '')
        user_message = build_user_message(booking)
        send_whatsapp(user_number, user_message)
        sent_count[:user] += 1
      end
      
      # Mark as sent to avoid duplicates
      booking.update(reminder_sent: true, reminder_sent_at: Time.current)
    end
    
    sent_count
  end
  
  private
  
  def self.build_admin_message(booking)
    match_time = "#{booking.slot.start_time} - #{booking.slot.end_time}"
    hours_until = calculate_hours_until_match(booking)
    
    <<~MSG
      *MATCH REMINDER - #{hours_until} HOURS*

      Ground: #{booking.ground.name}
      Location: #{booking.ground.location}
      Date: #{booking.booking_date}
      Time: #{match_time}

      Team: #{booking.user.name}
      Contact: #{booking.user.phone}
      Match Type: #{booking.match_type == "with_opponents" ? "With Opponents" : "Full Ground"}

      *Preparation Checklist:*
      □ Umpire Arranged
      □ Water Arranged
      □ Balls Ready
      □ Ground Ready

      Please update status in admin panel.
      — CrickOps
    MSG
  end
  
  def self.build_user_message(booking)
    match_time = "#{booking.slot.start_time} - #{booking.slot.end_time}"
    hours_until = calculate_hours_until_match(booking)
    
    <<~MSG
      *MATCH REMINDER - #{hours_until} HOURS*

      Ground: #{booking.ground.name}
      Location: #{booking.ground.location}
      Date: #{booking.booking_date}
      Time: #{match_time}

      Umpire: #{booking.umpire_name || "Will be assigned"}
      Groundsman: #{booking.groundsman_name || "Will be assigned"}

      Please arrive 10 minutes before your slot.
      Good luck and have a great match!

      — CrickOps
    MSG
  end
  
  def self.calculate_hours_until_match(booking)
    match_datetime = DateTime.parse("#{booking.booking_date} #{booking.slot.start_time}")
    hours = ((match_datetime - Time.current) / 1.hour).round
    hours = 12 if hours > 12
    hours
  end
  
  def self.send_whatsapp(phone, message)
    Rails.logger.info "WhatsApp to #{phone}: #{message}"
    # In production with WhatsApp Business API, uncomment:
    # client = WhatsAppClient.new
    # client.send_message(phone, message)
  end
end