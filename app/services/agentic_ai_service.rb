require 'httparty'
require 'json'

class AgenticAiService
  def initialize
    @api_key = ENV['GEMINI_API_KEY']
    @tools = {
      "list_grounds" => method(:list_grounds),
      "check_availability" => method(:check_availability),
      "book_slot" => method(:book_slot),
      "get_booking_status" => method(:get_booking_status),
      "cancel_booking" => method(:cancel_booking),
      "get_pricing" => method(:get_pricing),
      "get_slots" => method(:get_slots)
    }
  end

  def chat(message, user_context = {})
    intent = understand_intent(message)
    
    case intent[:action]
    when "list_grounds"
      return execute_list_grounds(message, user_context)
    when "check_availability"
      return execute_check_availability(message, user_context)
    when "book_slot"
      return execute_book_slot(message, user_context)
    when "get_booking_status"
      return execute_get_booking_status(user_context)
    when "cancel_booking"
      return execute_cancel_booking(message, user_context)
    when "get_pricing"
      return execute_get_pricing(message)
    when "get_slots"
      return execute_get_slots(message, user_context)
    else
      return execute_general_chat(message, user_context)
    end
  end

  private

  # ========== INTENT UNDERSTANDING ==========
  def understand_intent(message)
    msg = message.downcase
    
    if msg.match?(/\b(book|booking|reserve|schedule)\b/) && msg.match?(/\b(ground|slot)\b/)
      { action: "book_slot", params: extract_booking_params(message) }
    elsif msg.match?(/\b(available|free|open)\b/) && msg.match?(/\b(slot|time)\b/)
      { action: "check_availability", params: extract_date_params(message) }
    elsif msg.match?(/\b(list|show|display|all|what)\b/) && msg.match?(/\b(ground|grounds)\b/)
      { action: "list_grounds", params: {} }
    elsif msg.match?(/\b(my|my bookings|bookings)\b/)
      { action: "get_booking_status", params: {} }
    elsif msg.match?(/\b(cancel|remove|delete)\b/) && msg.match?(/\b(booking|slot)\b/)
      { action: "cancel_booking", params: extract_booking_id(message) }
    elsif msg.match?(/\b(price|cost|rate|how much)\b/)
      { action: "get_pricing", params: {} }
    elsif msg.match?(/\b(slot|time|timing)\b/)
      { action: "get_slots", params: extract_date_params(message) }
    else
      { action: "general_chat", params: { message: message } }
    end
  end

  # ========== EXTRACT PARAMETERS ==========
  def extract_booking_params(message)
    params = {}
    Ground.all.each do |ground|
      if message.downcase.include?(ground.name.downcase)
        params[:ground_id] = ground.id
        break
      end
    end
    
    date_match = message.match(/\d{4}-\d{2}-\d{2}/)
    params[:date] = date_match[0] if date_match
    
    time_match = message.match(/(\d{1,2}):(\d{2})/)
    params[:time] = time_match[0] if time_match
    
    if message.downcase.include?("without opponents")
      params[:match_type] = "without_opponents"
    else
      params[:match_type] = "with_opponents"
    end
    
    params
  end

  def extract_date_params(message)
    params = {}
    date_match = message.match(/\d{4}-\d{2}-\d{2}/)
    params[:date] = date_match[0] if date_match
    params
  end

  def extract_booking_id(message)
    id_match = message.match(/\b(\d+)\b/)
    { booking_id: id_match[0].to_i } if id_match
  end

  # ========== ACTIONS / TOOLS ==========
  def execute_list_grounds(message, user_context)
    grounds = Ground.all
    
    if grounds.empty?
      return "No grounds available yet. Please check back later."
    end
    
    response = "Here are all available grounds:\n\n"
    grounds.each do |g|
      response += "* #{g.name}\n"
      response += "  Location: #{g.location}\n"
      response += "  Price: Rs. #{g.price_per_hour}/hour\n"
      response += "  Timings: #{g.opening_time} - #{g.closing_time}\n"
      response += "  Amenities: #{g.amenities || 'Basic'}\n\n"
    end
    response += "Would you like to check availability for any of these grounds?"
    response
  end

  def execute_check_availability(message, user_context)
    grounds = Ground.all
    date = extract_date_params(message)[:date] || Date.today.to_s
    
    response = "Availability for #{date}:\n\n"
    
    grounds.each do |ground|
      slots = Slot.where(ground_id: ground.id, slot_date: date, status: "available")
      if slots.any?
        response += "[AVAILABLE] #{ground.name} has #{slots.count} available slots:\n"
        slots.each do |slot|
          response += "   • #{slot.start_time} - #{slot.end_time} (Rs. #{slot.price})\n"
        end
        response += "\n"
      else
        response += "[NOT AVAILABLE] #{ground.name} - No slots available\n\n"
      end
    end
    
    response += "Would you like to book a slot?"
    response
  end

  def execute_book_slot(message, user_context)
    if user_context[:user_id].blank?
      return "Please log in to book a slot."
    end
    
    params = extract_booking_params(message)
    
    if params[:ground_id].blank?
      return "Which ground would you like to book? Please specify the ground name."
    end
    
    if params[:date].blank?
      return "Please specify a date for your booking (format: YYYY-MM-DD)."
    end
    
    slot = Slot.find_by(
      ground_id: params[:ground_id],
      slot_date: params[:date],
      status: "available"
    )
    
    if slot.blank?
      return "No available slots for #{params[:date]}. Please try another date."
    end
    
    booking = Booking.new(
      user_id: user_context[:user_id],
      ground_id: params[:ground_id],
      slot_id: slot.id,
      booking_date: params[:date],
      match_type: params[:match_type],
      total_price: slot.price * (params[:match_type] == "without_opponents" ? 2 : 1),
      status: "pending",
      payment_status: "pending"
    )
    
    if booking.save
      slot.update!(teams_booked_count: slot.teams_booked_count.to_i + 1)
      if slot.teams_booked_count >= slot.max_teams
        slot.update!(status: "pending")
      end
      
      return "Booking created successfully!\n\nBooking ID: #{booking.id}\nGround: #{booking.ground.name}\nDate: #{booking.booking_date}\nTime: #{slot.start_time} - #{slot.end_time}\nPrice: Rs. #{booking.total_price}\nStatus: Pending confirmation\n\nAdmin will confirm your booking shortly. You will receive WhatsApp confirmation!"
    else
      return "Failed to create booking. #{booking.errors.full_messages.join(', ')}"
    end
  end

  def execute_get_booking_status(user_context)
    if user_context[:user_id].blank?
      return "Please log in to view your bookings."
    end
    
    bookings = Booking.where(user_id: user_context[:user_id]).order(created_at: :desc).limit(5)
    
    if bookings.empty?
      return "You have no bookings yet. Would you like to book a ground?"
    end
    
    response = "Your recent bookings:\n\n"
    bookings.each do |b|
      status_indicator = b.status == "confirmed" ? "[CONFIRMED]" : (b.status == "cancelled" ? "[CANCELLED]" : "[PENDING]")
      response += "#{status_indicator} Booking ##{b.id}\n"
      response += "   Ground: #{b.ground.name}\n"
      response += "   Date: #{b.booking_date}\n"
      response += "   Time: #{b.slot.start_time} - #{b.slot.end_time}\n"
      response += "   Price: Rs. #{b.total_price}\n"
      response += "   Status: #{b.status}\n\n"
    end
    response
  end

  def execute_cancel_booking(message, user_context)
    if user_context[:user_id].blank?
      return "Please log in to cancel a booking."
    end
    
    params = extract_booking_id(message)
    
    if params[:booking_id].blank?
      return "Please provide the booking ID to cancel. You can find it in 'My Bookings'."
    end
    
    booking = Booking.find_by(id: params[:booking_id], user_id: user_context[:user_id])
    
    if booking.blank?
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
    
    return "Booking #{booking.id} cancelled successfully!\nRefund: #{refund_percentage}% (Rs. #{booking.total_price * refund_percentage / 100})\n\nIf you have any questions, contact support."
  end

  def execute_get_pricing(message)
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

  def execute_get_slots(message, user_context)
    date = extract_date_params(message)[:date] || Date.today.to_s
    
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
    response += "To book, say: 'Book a slot at [ground name] on [date]'"
    response
  end

  def execute_general_chat(message, user_context)
    return fallback_response(message) if @api_key.blank?
    
    prompt = <<~PROMPT
      You are CrickOps AI Assistant. You can help users book cricket grounds, check availability, manage bookings, and answer questions.
      
      Current time: #{Time.current.strftime("%Y-%m-%d %H:%M")}
      
      User message: #{message}
      
      Respond helpfully and concisely. If the user wants to book, ask for details. Be friendly.
    PROMPT
    
    url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-001:generateContent?key=#{@api_key}"
    
    response = HTTParty.post(
      url,
      headers: { "Content-Type" => "application/json" },
      body: {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.7, maxOutputTokens: 300 }
      }.to_json
    )
    
    if response.success?
      result = response.parsed_response
      result.dig("candidates", 0, "content", "parts", 0, "text") || fallback_response(message)
    else
      fallback_response(message)
    end
  end

  def fallback_response(message)
    msg = message.downcase
    if msg.include?("book")
      "I can help you book a slot! Please tell me: Which ground? What date? (YYYY-MM-DD) What time? (HH:MM)"
    elsif msg.include?("ground")
      "Would you like me to list all grounds or check availability for a specific one?"
    else
      "I'm your CrickOps assistant! I can help you:\n• Book a slot\n• Check availability\n• View your bookings\n• Cancel a booking\n• Get pricing info\n\nWhat would you like to do?"
    end
  end
end