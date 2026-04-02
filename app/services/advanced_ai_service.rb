class AdvancedAiService
  def chat(message, user_context = {})
    msg = message.downcase
    grounds = Ground.all.to_a

    # Booking help
    if msg.include?("book")
      return <<~TEXT
        To book a slot:
        1. Go to Grounds page
        2. Select a ground
        3. Choose a date
        4. Pick a time slot
        5. Select match type (With Opponents / Without Opponents)
        6. Click "Book Now"
        You'll receive WhatsApp confirmation.
      TEXT
    end

    # Cancellation policy
    if msg.include?("cancel")
      return <<~TEXT
        Cancellation Policy:
        • Cancel >3 days before match → 100% refund
        • Cancel 2-3 days before → 25% refund
        • Cancel <48 hours → No refund
      TEXT
    end

    # Pricing
    if msg.include?("price") || msg.include?("cost")
      return <<~TEXT
        Pricing (per 3-hour slot):
        Weekdays (Mon-Fri): ₹2500
        Weekends (Sat-Sun): Morning ₹4000, Mid-Day ₹3500, Evening ₹3000
        Without Opponents: 2x price
      TEXT
    end

    # Slot timings
    if msg.include?("slot") || msg.include?("time")
      return <<~TEXT
        Slot Timings:
        Morning: 6:30 – 9:30
        Mid-Day: 9:30 – 12:30
        Evening: 13:00 – 18:00
      TEXT
    end

    # Ground recommendations
    if grounds.any? && msg.include?("ground")
      # Price filter
      if msg =~ /under\s+(\d+)/
        max_price = $1.to_i
        affordable = grounds.select { |g| g.price_per_hour <= max_price }
        if affordable.any?
          response = "Grounds under ₹#{max_price}:\n"
          affordable.each { |g| response += "• #{g.name}: ₹#{g.price_per_hour}/hour, #{g.location}\n" }
          return response
        else
          cheapest = grounds.min_by(&:price_per_hour)
          return "No grounds under ₹#{max_price}. The cheapest is #{cheapest.name} at ₹#{cheapest.price_per_hour}/hour."
        end
      end

      # Location filter
      locations = ["bangalore", "btm", "varthur", "sarjapura"]
      locations.each do |loc|
        if msg.include?(loc)
          filtered = grounds.select { |g| g.location.downcase.include?(loc) }
          if filtered.any?
            response = "Grounds in #{loc.capitalize}:\n"
            filtered.each { |g| response += "• #{g.name}: ₹#{g.price_per_hour}/hour\n" }
            return response
          else
            return "No grounds found in #{loc.capitalize}."
          end
        end
      end

      # Cheapest
      if msg.include?("cheapest")
        cheapest = grounds.min_by(&:price_per_hour)
        return "The cheapest ground is #{cheapest.name} at ₹#{cheapest.price_per_hour}/hour in #{cheapest.location}."
      end

      # Default – show top 3
      top = grounds.first(3)
      response = "Here are some grounds:\n"
      top.each { |g| response += "• #{g.name}: ₹#{g.price_per_hour}/hour, #{g.location}\n" }
      return response
    end

    # Greeting
    if msg.match?(/\b(hi|hello|hey)\b/)
      return "Hello! I'm your CrickOps assistant. I can help with bookings, cancellations, pricing, slot timings, and finding grounds. What would you like to know?"
    end

    # Default help
    return <<~TEXT
      I'm your CrickOps assistant. You can ask me about:
      • How to book a slot
      • Cancellation policy
      • Pricing
      • Slot timings
      • Grounds under a price (e.g., "ground under 2000")
      • Grounds in a location (e.g., "ground in Bangalore")
      • The cheapest ground
    TEXT
  end
end