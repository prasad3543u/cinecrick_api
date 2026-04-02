class AdvancedAiService
  def chat(message)
    msg = message.downcase

    # Simple responses for common queries
    if msg.include?("book")
      return "To book a slot: Go to Grounds page, select a ground, choose a date, pick a time slot, select match type, and click 'Book Now'. You'll receive WhatsApp confirmation."
    end

    if msg.include?("cancel")
      return "Cancellation policy: 100% refund if cancelled more than 3 days before match, 25% refund if cancelled 2-3 days before, no refund within 48 hours."
    end

    if msg.include?("price") || msg.include?("cost")
      return "Pricing: Weekdays Rs. 2500 per slot. Weekends: Morning Rs. 4000, Mid-Day Rs. 3500, Evening Rs. 3000. Without Opponents: double price."
    end

    if msg.include?("slot") || msg.include?("time")
      return "Slot timings: Morning 6:30-9:30, Mid-Day 9:30-12:30, Evening 13:00-18:00."
    end

    if msg.include?("ground") && (msg.include?("under") || msg.include?("below"))
      if msg =~ /under\s+(\d+)/
        max_price = $1.to_i
        grounds = Ground.where("price_per_hour <= ?", max_price).limit(3)
        if grounds.any?
          response = "Grounds under Rs. #{max_price}:\n"
          grounds.each { |g| response += "• #{g.name}: Rs. #{g.price_per_hour}/hour, #{g.location}\n" }
          return response
        else
          return "No grounds under Rs. #{max_price}."
        end
      end
    end

    if msg.include?("ground") && (msg.include?("bangalore") || msg.include?("location"))
      grounds = Ground.where("location ILIKE ?", "%bangalore%").limit(3)
      if grounds.any?
        response = "Grounds in Bangalore:\n"
        grounds.each { |g| response += "• #{g.name}: Rs. #{g.price_per_hour}/hour\n" }
        return response
      else
        return "No grounds found in Bangalore."
      end
    end

    if msg.include?("ground")
      grounds = Ground.limit(3)
      if grounds.any?
        response = "Here are some grounds:\n"
        grounds.each { |g| response += "• #{g.name}: Rs. #{g.price_per_hour}/hour, #{g.location}\n" }
        return response
      else
        return "No grounds available yet."
      end
    end

    if msg.match?(/\b(hi|hello|hey)\b/)
      return "Hello! I'm your CrickOps assistant. I can help with bookings, cancellations, pricing, slot timings, and finding grounds. What would you like to know?"
    end

    "I'm your CrickOps assistant. You can ask me about bookings, cancellations, pricing, slot timings, or grounds (e.g., 'ground under 2000', 'ground in Bangalore')."
  end
end