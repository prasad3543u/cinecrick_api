# app/services/advanced_ai_service.rb
class AdvancedAiService
  def chat(message)
    msg = message.downcase
    grounds = Ground.all.to_a

    # --- Booking help ---
    if msg.include?("book")
      return <<~TEXT
        To book a slot on CrickOps:

        1. Browse Grounds – Find a ground you like.
        2. Select Date – Pick a date from the calendar.
        3. Choose Slot – Morning (6:30-9:30), Mid-Day (9:30-12:30), or Evening (13:00-18:00).
        4. Pick Match Type – "With Opponents" (needs another team) or "Without Opponents" (you take the whole ground).
        5. Confirm – Click "Book Now". A WhatsApp request will be sent to the admin.
        6. Admin Confirms – You'll receive a WhatsApp confirmation once approved.

        Your booking will appear in "My Bookings" shortly.
      TEXT
    end

    # --- Cancellation policy ---
    if msg.include?("cancel")
      return <<~TEXT
        Cancellation Policy:

        • Cancel more than 3 days before match → 100% refund
        • Cancel 2 to 3 days before → 25% refund
        • Cancel within 48 hours → No refund

        To cancel, go to "My Bookings" and click "Cancel Booking". Refund will be processed automatically.
      TEXT
    end

    # --- Pricing ---
    if msg.include?("price") || msg.include?("cost")
      return <<~TEXT
        Pricing (per 3-hour slot):

        Weekdays (Mon-Fri)     → Rs. 2500
        Weekends (Sat-Sun)     → Morning (6:30-9:30) Rs. 4000, Mid-Day Rs. 3500, Evening Rs. 3000
        Without Opponents      → 2x price (you book the whole ground)

        Prices may vary by ground – check individual ground pages.
      TEXT
    end

    # --- Slot timings ---
    if msg.include?("slot") || msg.include?("time")
      return <<~TEXT
        Daily Slot Timings:

        Morning   06:30 – 09:30
        Mid-Day   09:30 – 12:30
        Evening   13:00 – 18:00

        Weekend slots may have different pricing.
      TEXT
    end

    # --- Ground recommendations (using real data) ---
    if grounds.any? && msg.include?("ground")
      # Price filter (e.g., "under 2000", "below 1500")
      if msg =~ /under\s+(\d+)/
        max_price = $1.to_i
        affordable = grounds.select { |g| g.price_per_hour <= max_price }
        if affordable.any?
          response = "Grounds under Rs. #{max_price}:\n"
          affordable.each { |g| response += "• #{g.name}: Rs. #{g.price_per_hour}/hour, #{g.location}\n" }
          return response
        else
          cheapest = grounds.min_by(&:price_per_hour)
          return "No grounds under Rs. #{max_price}. The cheapest is #{cheapest.name} at Rs. #{cheapest.price_per_hour}/hour."
        end
      end

      # Location filter
      locations = ["bangalore", "btm", "varthur", "sarjapura", "whitefield", "indiranagar"]
      locations.each do |loc|
        if msg.include?(loc)
          filtered = grounds.select { |g| g.location.downcase.include?(loc) }
          if filtered.any?
            response = "Grounds in #{loc.capitalize}:\n"
            filtered.each { |g| response += "• #{g.name}: Rs. #{g.price_per_hour}/hour\n" }
            return response
          else
            return "No grounds found in #{loc.capitalize}."
          end
        end
      end

      # Cheapest
      if msg.include?("cheapest") || msg.include?("lowest price")
        cheapest = grounds.min_by(&:price_per_hour)
        return "The cheapest ground is #{cheapest.name} at Rs. #{cheapest.price_per_hour}/hour in #{cheapest.location}."
      end

      # Most expensive / premium
      if msg.include?("expensive") || msg.include?("premium") || msg.include?("luxury")
        expensive = grounds.max_by(&:price_per_hour)
        return "The most premium ground is #{expensive.name} at Rs. #{expensive.price_per_hour}/hour in #{expensive.location}."
      end

      # Default – show top 3 grounds
      top = grounds.first(3)
      response = "Here are some grounds:\n"
      top.each { |g| response += "• #{g.name}: Rs. #{g.price_per_hour}/hour, #{g.location}\n" }
      return response
    end

    # --- Greeting ---
    if msg.match?(/\b(hi|hello|hey|greetings)\b/)
      return "Hello! I'm your CrickOps assistant. I can help you with bookings, cancellations, pricing, slot timings, and finding grounds. What would you like to know?"
    end

    # --- Default help menu ---
    <<~TEXT
      I'm your CrickOps assistant. You can ask me about:
      • How to book a slot
      • Cancellation policy
      • Pricing
      • Slot timings
      • Grounds under a price (e.g., "ground under 2000")
      • Grounds in a location (e.g., "ground in Bangalore")
      • The cheapest or most expensive ground

      Just ask naturally!
    TEXT
  end
end