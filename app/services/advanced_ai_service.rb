class AdvancedAiService
  def initialize
    @grounds = Ground.all.to_a
    @bookings = Booking.all
  end

  def chat(message, user_context = {})
    msg = message.downcase
    response = nil

    # 1. Booking help
    if msg.include?("book") && (msg.include?("how") || msg.include?("steps") || msg.include?("process"))
      response = booking_help
    end

    # 2. Cancellation policy
    if msg.include?("cancel") || msg.include?("refund")
      response = cancellation_policy
    end

    # 3. Pricing
    if msg.include?("price") || msg.include?("cost") || msg.include?("how much")
      response = pricing_info
    end

    # 4. Slot timings
    if msg.include?("slot") || msg.include?("time") || msg.include?("timing")
      response = slot_timings
    end

    # 5. Ground recommendations (most complex)
    if msg.include?("ground") || msg.include?("grounds")
      response = recommend_grounds(msg)
    end

    # 6. Greeting
    if msg.match?(/\b(hi|hello|hey|greetings)\b/)
      response = greeting
    end

    # 7. Default help
    response ||= help_menu

    response
  end

  private

  def booking_help
    <<~TEXT
      To book a slot on CrickOps:

      1️⃣ Browse Grounds – Find a ground you like.
      2️⃣ Select Date – Pick a date from the calendar.
      3️⃣ Choose Slot – Morning (6:30‑9:30), Mid‑Day (9:30‑12:30), or Evening (13:00‑18:00).
      4️⃣ Pick Match Type – "With Opponents" (needs another team) or "Without Opponents" (you take the whole ground).
      5️⃣ Confirm – Click "Book Now". A WhatsApp request will be sent to the admin.
      6️⃣ Admin Confirms – You'll receive a WhatsApp confirmation once approved.

      Your booking will appear in "My Bookings" shortly.
    TEXT
  end

  def cancellation_policy
    <<~TEXT
      Cancellation Policy:

      • More than 3 days before match → 100% refund
      • 2 to 3 days before match → 25% refund
      • Within 48 hours → No refund

      To cancel, go to "My Bookings" and click "Cancel Booking". The refund will be processed automatically.
    TEXT
  end

  def pricing_info
    <<~TEXT
      Pricing (per 3‑hour slot):

      Weekdays (Mon‑Fri)     → ₹2500
      Weekends (Sat‑Sun)     → Morning (6:30‑9:30) ₹4000, Mid‑Day ₹3500, Evening ₹3000
      Without Opponents      → 2x price (you book the whole ground)

      Prices may vary by ground – check individual ground pages.
    TEXT
  end

  def slot_timings
    <<~TEXT
      Daily Slot Timings:

      🌅 Morning   06:30 – 09:30
      ☀️ Mid‑Day   09:30 – 12:30
      🌙 Evening   13:00 – 18:00

      Weekend slots may have different pricing.
    TEXT
  end

  def recommend_grounds(msg)
    return "No grounds available yet." if @grounds.empty?

    # Filter by price (e.g., "under 2000", "below 1500", "around 2500")
    price_filter = extract_price_filter(msg)
    if price_filter
      grounds = filter_by_price(price_filter[:max])
      if grounds.any?
        response = "Grounds #{price_filter[:text]} ₹#{price_filter[:max]}:\n"
        response += format_ground_list(grounds)
        return response
      else
        cheapest = @grounds.min_by(&:price_per_hour)
        return "No grounds #{price_filter[:text]} ₹#{price_filter[:max]}. The cheapest is #{cheapest.name} at ₹#{cheapest.price_per_hour}/hour in #{cheapest.location}."
      end
    end

    # Filter by location
    location = extract_location(msg)
    if location
      grounds = @grounds.select { |g| g.location.downcase.include?(location) }
      if grounds.any?
        response = "Grounds in #{location.capitalize}:\n"
        response += format_ground_list(grounds)
        return response
      else
        return "No grounds found in #{location.capitalize}. Try Bangalore, Sarjapura, Varthur, BTM, etc."
      end
    end

    # Filter by amenities (e.g., "floodlights", "parking")
    amenity = extract_amenity(msg)
    if amenity
      grounds = @grounds.select { |g| g.amenities.to_s.downcase.include?(amenity) }
      if grounds.any?
        response = "Grounds with #{amenity.capitalize}:\n"
        response += format_ground_list(grounds)
        return response
      else
        return "No grounds with #{amenity.capitalize} found."
      end
    end

    # Cheapest ground
    if msg.include?("cheapest") || msg.include?("lowest price")
      cheapest = @grounds.min_by(&:price_per_hour)
      return "The cheapest ground is #{cheapest.name} at ₹#{cheapest.price_per_hour}/hour in #{cheapest.location}."
    end

    # Most expensive / premium
    if msg.include?("expensive") || msg.include?("premium") || msg.include?("luxury")
      most_expensive = @grounds.max_by(&:price_per_hour)
      return "The most premium ground is #{most_expensive.name} at ₹#{most_expensive.price_per_hour}/hour in #{most_expensive.location}."
    end

    # Default – show top grounds
    top = @grounds.first(3)
    response = "Here are some grounds:\n"
    response += format_ground_list(top)
    response += "\nWould you like to filter by price, location, or amenities?"
    response
  end

  def extract_price_filter(msg)
    # Match patterns like "under 2000", "below 1500", "around 2500", "less than 3000"
    patterns = [
      /under\s*(\d+)/,
      /below\s*(\d+)/,
      /around\s*(\d+)/,
      /less\s*than\s*(\d+)/,
      /₹?(\d+)\s*per\s*hour/,
      /max\s*(\d+)/
    ]
    patterns.each do |pattern|
      if match = msg.match(pattern)
        max_price = match[1].to_i
        text = msg.include?("under") ? "under" : (msg.include?("below") ? "below" : "around")
        return { max: max_price, text: text }
      end
    end
    nil
  end

  def extract_location(msg)
    locations = ["bangalore", "btm", "varthur", "sarjapura", "whitefield", "indiranagar", "koramangala", "electronic city"]
    locations.find { |loc| msg.include?(loc) }
  end

  def extract_amenity(msg)
    amenities = ["floodlights", "parking", "changing room", "cafeteria", "canteen", "lights", "parking lot"]
    amenities.find { |a| msg.include?(a) }
  end

  def filter_by_price(max_price)
    @grounds.select { |g| g.price_per_hour <= max_price }
  end

  def format_ground_list(grounds)
    grounds.map { |g| "• #{g.name}: ₹#{g.price_per_hour}/hour, #{g.location}" }.join("\n")
  end

  def greeting
    "Hello! I'm your CrickOps assistant. I can help you with bookings, cancellations, pricing, slot timings, and finding grounds.\n\n" + help_menu
  end

  def help_menu
    <<~TEXT
      What would you like to know?

      • How to book a slot
      • Cancellation policy
      • Pricing
      • Slot timings
      • Grounds under a price (e.g., "ground under 2000")
      • Grounds in a location (e.g., "ground in Bangalore")
      • Grounds with amenities (e.g., "ground with floodlights")
      • Cheapest ground
      • Most expensive ground

      Just ask naturally!
    TEXT
  end
end