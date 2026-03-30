class AgenticAiService
  def initialize
    @api_key = ENV['GEMINI_API_KEY']
  end

  def chat(message, user_context = {})
    msg = message.downcase
    
    # List grounds
    if msg.include?("ground") && (msg.include?("list") || msg.include?("show") || msg.include?("all"))
      return list_grounds
    end
    
    # Check availability
    if msg.include?("available") && msg.include?("slot")
      return check_availability(message)
    end
    
    # Book a slot
    if msg.include?("book") && msg.include?("slot")
      return book_slot(message, user_context)
    end
    
    # View bookings
    if msg.include?("my") && msg.include?("booking")
      return get_booking_status(user_context)
    end
    
    # Cancel booking
    if msg.include?("cancel") && msg.include?("booking")
      return cancel_booking(message, user_context)
    end
    
    # Pricing
    if msg.include?("price") || msg.include?("cost")
      return get_pricing
    end
    
    # Slots for a date
    if msg.include?("slot") && msg.include?("date")
      return get_slots(message)
    end
    
    # Greeting
    if msg.include?("hi") || msg.include?("hello")
      return "Hello! I'm your CrickOps assistant. I can help you with bookings, grounds, prices, and cancellations. What would you like to know?"
    end
    
    # Default response
    "I'm your CrickOps assistant! I can help you with:\n• List grounds\n• Check availability\n• Book a slot\n• View your bookings\n• Cancel a booking\n• Get pricing\n\nWhat would you like to do?"
  end

  private

  def list_grounds
    grounds = Ground.all
    if grounds.empty?
      return "No grounds available yet. Please check back later."
    end
    
    response = "Here are all available grounds:\n\n"
    grounds.each do |g|
      response += "* #{g.name}\n"
      response += "  Location: #{g.location}\n"
      response += "  Price: Rs. #{g.price_per_hour}/hour\n"
      response += "  Timings: #{g.opening_time} - #{g.closing_time}\n\n"
    end
    response
  end

  def check_availability(message)
    # Extract date from message
    date_match = message.match(/\d{4}-\d{2}-\d{2}/)
    date = date_match ? date_match[0] : Date.today.to_s
    
    grounds = Ground.all
    response = "Availability for #{date}:\n\n"
    
    grounds.each do |ground|
      slots = Slot.where(ground_id: ground.id, slot_date: date, status: "available")
      if slots.any?
        response += "[AVAILABLE] #{ground.name}\n"
        slots.each do |slot|
          response += "   • #{slot.start_time} - #{slot.end_time} (Rs. #{slot.price})\n"
        end
        response += "\n"
      else
        response += "[NOT AVAILABLE] #{ground.name} - No slots\n\n"
      end
    end
    response
  end

  def book_slot(message, user_context)
    if user_context[:user_id].blank?
      return "Please log in to book a slot."
    end
    
    # Find ground
    ground = nil
    Ground.all.each do |g|
      if message.downcase.include?(g.name.downcase)
        ground = g
        break
      end
    end
    
    if ground.nil?
      return "Which ground would you like to book? Please specify the ground name."
    end
    
    # Find date
    date_match = message.match(/\d{4}-\d{2}-\d{2}/)
    if date_match.nil?
      return "Please specify a date for your booking (format: YYYY-MM-DD)."
    end
    date = date_match[0]
    
    # Find available slot
    slot = Slot.find_by(ground_id: ground.id, slot_date: date, status: "available")
    if slot.nil?
      return "No available slots for #{date}. Please try another date."
    end
    
    # Determine match type
    match_type = message.downcase.include?("without opponents") ? "without_opponents" : "with_opponents"
    total_price = match_type == "without_opponents" ? slot.price * 2 : slot.price
    
    # Create booking
    booking = Booking.new(
      user_id: user_context[:user_id],
      ground_id: ground.id,
      slot_id: slot.id,
      booking_date: date,
      match_type: match_type,
      total_price: total_price,
      status: "pending",
      payment_status: "pending"
    )
    
    if booking.save
      slot.update!(teams_booked_count: slot.teams_booked_count.to_i + 1)
      if slot.teams_booked_count >= slot.max_teams
        slot.update!(status: "pending")
      end
      
      return "Booking created successfully!\n\nBooking ID: #{booking.id}\nGround: #{ground.name}\nDate: #{date}\nTime: #{slot.start_time} - #{slot.end_time}\nPrice: Rs. #{total_price}\nStatus: Pending confirmation\n\nAdmin will confirm your booking shortly."
    else
      return "Failed to create booking: #{booking.errors.full_messages.join(', ')}"
    end
  end

  def get_booking_status(user_context)
    if user_context[:user_id].blank?
      return "Please log in to view your bookings."
    end
    
    bookings = Booking.where(user_id: user_context[:user_id]).order(created_at: :desc).limit(5)
    
    if bookings.empty?
      return "You have no bookings yet. Would you like to book a ground?"
    end
    
    response = "Your recent bookings:\n\n"
    bookings.each do |b|
      status_tag = b.status == "confirmed" ? "[CONFIRMED]" : (b.status == "cancelled" ? "[CANCELLED]" : "[PENDING]")
      response += "#{status_tag} Booking ##{b.id}\n"
      response += "   Ground: #{b.ground.name}\n"
      response += "   Date: #{b.booking_date}\n"
      response += "   Time: #{b.slot.start_time} - #{b.slot.end_time}\n"
      response += "   Price: Rs. #{b.total_price}\n"
      response += "   Status: #{b.status}\n\n"
    end
    response
  end

  def cancel_booking(message, user_context)
    if user_context[:user_id].blank?
      return "Please log in to cancel a booking."
    end
    
    id_match = message.match(/\b(\d+)\b/)
    if id_match.nil?
      return "Please provide the booking ID to cancel. Example: 'Cancel booking 45'"
    end
    booking_id = id_match[1].to_i
    
    booking = Booking.find_by(id: booking_id, user_id: user_context[:user_id])
    if booking.nil?
      return "Booking not found. Please check the booking ID."
    end
    
    if booking.status != "pending" && booking.status != "confirmed"
      return "This booking cannot be cancelled (Status: #{booking.status})."
    end
    
    if booking.booking_date < Date.today
      return "Cannot cancel past bookings."
    end
    
    hours_diff = (booking.booking_date.to_time - Time.current) / 3600
    refund_percentage = hours_diff > 72 ? 100 : (hours_diff > 48 ? 25 : 0)
    
    booking.update!(status: "cancelled")
    
    slot = booking.slot
    slot.update!(teams_booked_count: slot.teams_booked_count.to_i - 1)
    if slot.teams_booked_count.to_i < slot.max_teams
      slot.update!(status: "available")
    end
    
    refund_amount = booking.total_price * refund_percentage / 100
    return "Booking #{booking_id} cancelled successfully!\nRefund: #{refund_percentage}% (Rs. #{refund_amount})\n\nContact support if you have questions."
  end

  def get_pricing
    response = "CrickOps Pricing Guide\n\n"
    response += "Weekdays (Monday-Friday)\n"
    response += "• Any slot: Rs. 2500 for 3 hours\n\n"
    response += "Weekends (Saturday-Sunday)\n"
    response += "• Morning (6:30-9:30): Rs. 4000\n"
    response += "• Mid-Day (9:30-12:30): Rs. 3500\n"
    response += "• Evening (13:00-18:00): Rs. 3000\n\n"
    response += "Match Types\n"
    response += "• With Opponents: Standard price\n"
    response += "• Without Opponents: 2x price (full ground)\n\n"
    response += "Prices vary by ground. Check ground page for exact rates."
    response
  end

  def get_slots(message)
    date_match = message.match(/\d{4}-\d{2}-\d{2}/)
    date = date_match ? date_match[0] : Date.today.to_s
    
    slots = Slot.where(slot_date: date, status: "available")
    
    if slots.empty?
      return "No available slots for #{date}. Try another date!"
    end
    
    response = "Available slots for #{date}:\n\n"
    slots.group_by(&:ground).each do |ground, ground_slots|
      response += "* #{ground.name}\n"
      ground_slots.each do |slot|
        response += "   • #{slot.start_time} - #{slot.end_time} (Rs. #{slot.price})\n"
      end
      response += "\n"
    end
    response
  end
end