require "httparty"

class AdvancedAiService
  GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

  def chat(message, history = [])
    api_key = ENV["GEMINI_API_KEY"]
    return fallback_response(message) unless api_key.present?

    # Fetch live ground data to give Gemini real context
    grounds_info = build_grounds_context

    system_prompt = <<~PROMPT
      You are CrickOps AI Assistant — a helpful assistant for a cricket ground booking platform called CrickOps.

      Your job is to help users with:
      1. Finding and recommending cricket grounds
      2. Explaining how to book slots
      3. Answering questions about pricing, timings, cancellation policies
      4. General cricket knowledge and rules
      5. Helping admins with operations (umpire assignment, reminders, match day prep)

      PLATFORM INFORMATION:
      - Platform: CrickOps — Cricket Ground Management & Booking Platform
      - Location: India (prices in Indian Rupees)

      BOOKING PROCESS:
      1. Go to Grounds page
      2. Select a ground
      3. Choose a date and time slot
      4. Select match type: "With Opponents" or "Without Opponents"
      5. Click Book Now
      6. Admin confirms booking and assigns umpire + groundsman
      7. User receives WhatsApp confirmation with staff details

      SLOT TIMINGS:
      - Morning: 6:30 AM - 9:30 AM
      - Mid-Day: 9:30 AM - 12:30 PM
      - Evening: 1:00 PM - 6:00 PM

      PRICING:
      - Weekdays: Rs. 2500 per slot
      - Weekend Morning: Rs. 4000
      - Weekend Mid-Day: Rs. 3500
      - Weekend Evening: Rs. 3000
      - Without Opponents (full ground): double the slot price

      CANCELLATION POLICY:
      - Pending bookings: can be cancelled anytime, no charges
      - Confirmed bookings: cancellation not allowed
      - Past bookings: cannot be cancelled

      WHAT'S INCLUDED IN EVERY BOOKING:
      - Umpire (assigned by admin after confirmation)
      - Groundsman (for pitch preparation, water, old balls)
      - Ground setup

      MATCH TYPES:
      - With Opponents: book one team slot, opponent books separately
      - Without Opponents: book full ground, pay for both team slots

      AVAILABLE GROUNDS:
      #{grounds_info}

      ADMIN OPERATIONS:
      - Admin confirms bookings from Admin Bookings page
      - Admin assigns umpire name + phone to confirmed bookings
      - Admin assigns groundsman name + phone
      - Match day status tracking: Umpire Reached, Water Arranged, Balls Ready, Ground Ready
      - Today's Matches dashboard shows all today's confirmed bookings
      - Send All Reminders button sends WhatsApp to all teams at once

      IMPORTANT RULES:
      - Always be helpful, friendly and concise
      - Keep responses under 150 words unless detailed explanation is needed
      - Use bullet points for lists
      - Always mention prices in Rs. (Indian Rupees)
      - If asked about something unrelated to cricket or CrickOps, politely redirect
    PROMPT

    # Build conversation history for Gemini
    contents = []

    # Add history
    history.each do |msg|
      contents << {
        role: msg["role"] == "user" ? "user" : "model",
        parts: [{ text: msg["content"] }]
      }
    end

    # Add current message
    contents << {
      role: "user",
      parts: [{ text: message }]
    }

    body = {
      system_instruction: {
        parts: [{ text: system_prompt }]
      },
      contents: contents,
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 500,
        topP: 0.8
      }
    }

    response = HTTParty.post(
      "#{GEMINI_URL}?key=#{api_key}",
      headers: { "Content-Type" => "application/json" },
      body: body.to_json,
      timeout: 15
    )

    if response.success?
      text = response.dig("candidates", 0, "content", "parts", 0, "text")
      text.present? ? text.strip : fallback_response(message)
    else
      Rails.logger.error("Gemini API error: #{response.code} — #{response.body}")
      fallback_response(message)
    end

  rescue => e
    Rails.logger.error("Gemini service error: #{e.message}")
    fallback_response(message)
  end

  private

  def build_grounds_context
    grounds = Ground.all
    return "No grounds available yet." if grounds.empty?

    grounds.map do |g|
      "- #{g.name} | Location: #{g.location} | Price: Rs. #{g.price_per_hour}/hr | Sport: #{g.sport_type}"
    end.join("\n")
  rescue
    "Ground information unavailable."
  end

  def fallback_response(message)
    msg = message.downcase

    return "To book a slot: Go to Grounds → select a ground → choose date → pick slot → select match type → click Book Now. Admin will confirm and assign umpire." if msg.include?("book")
    return "Cancellation: Pending bookings can be cancelled anytime. Confirmed bookings cannot be cancelled." if msg.include?("cancel")
    return "Pricing: Weekdays Rs. 2500. Weekends: Morning Rs. 4000, Mid-Day Rs. 3500, Evening Rs. 3000. Without Opponents: double price." if msg.include?("price") || msg.include?("cost")
    return "Slot timings: Morning 6:30-9:30, Mid-Day 9:30-12:30, Evening 13:00-18:00." if msg.include?("slot") || msg.include?("time")
    return "Hello! I'm your CrickOps assistant. Ask me about bookings, pricing, slots, or grounds!" if msg.match?(/\b(hi|hello|hey)\b/)

    "I'm your CrickOps AI assistant. Ask me about bookings, cancellations, pricing, slot timings, or finding grounds."
  end
end