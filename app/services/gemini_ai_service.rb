require 'httparty'

class GeminiAiService
  def initialize
    @api_key = ENV['GEMINI_API_KEY']
  end

  def chat(message, user_context = {})
    # Always try Gemini first if API key exists
    if @api_key.present?
      result = try_gemini(message, user_context)
      return result if result.present?
    end
    
    # Fallback to smart responses if Gemini fails or no API key
    smart_fallback(message)
  end

  private

  def try_gemini(message, user_context)
    grounds_data = get_grounds_data
    bookings_data = get_bookings_data
    
    prompt = <<~PROMPT
      You are CrickOps AI Assistant. Answer based on REAL DATA below.

      REAL GROUNDS DATA:
      #{grounds_data}

      REAL BOOKINGS STATS:
      #{bookings_data}

      CANCELLATION POLICY:
      - Cancel >3 days before match: 100% refund
      - Cancel 2-3 days before: 25% refund
      - Cancel <48 hours: No refund

      PRICING:
      - Weekdays (Mon-Fri): ₹2500 per 3-hour slot
      - Weekends (Sat-Sun): ₹4000 (6:30-9:30), ₹3500 (9:30-12:30), ₹3000 (13:00-18:00)
      - Without Opponents: 2x price (full ground booking)

      USER CONTEXT:
      - Role: #{user_context[:role] || 'User'}
      - Past Bookings: #{user_context[:bookings_count] || 0}

      USER QUESTION: "#{message}"

      RULES:
      1. Use ONLY the REAL GROUNDS DATA above. Don't make up grounds.
      2. Be specific with ground names, locations, and actual prices.
      3. Keep response under 150 words.
      4. Be friendly and helpful.

      YOUR RESPONSE:
    PROMPT

    begin
      # Use the stable Gemini model
      model = "gemini-2.0-flash-001"
      url = "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{@api_key}"
      
      Rails.logger.info "Calling Gemini API with model: #{model}"
      
      response = HTTParty.post(
        url,
        headers: { "Content-Type" => "application/json" },
        body: {
          contents: [{
            parts: [{ text: prompt }]
          }],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 500
          }
        }.to_json
      )

      if response.success?
        result = response.parsed_response
        ai_response = result.dig("candidates", 0, "content", "parts", 0, "text")
        Rails.logger.info "Gemini Response received successfully"
        return ai_response if ai_response.present?
      else
        Rails.logger.error "Gemini API Error: #{response.body}"
        return nil
      end
    rescue => e
      Rails.logger.error "Gemini Error: #{e.message}"
      return nil
    end
    
    nil
  end

  def get_grounds_data
    grounds = Ground.all
    if grounds.any?
      grounds.map do |g|
        "- #{g.name}: ₹#{g.price_per_hour}/hour, Location: #{g.location}, Amenities: #{g.amenities || 'Basic'}"
      end.join("\n")
    else
      "No grounds added yet. Admin can add grounds in admin panel."
    end
  end

  def get_bookings_data
    total = Booking.count
    confirmed = Booking.where(status: "confirmed").count
    "Total Bookings: #{total}, Confirmed: #{confirmed}"
  end

  def smart_fallback(message)
    msg = message.downcase
    grounds = Ground.all
    
    if grounds.any?
      # Check for price-based queries
      if msg.include?("under") || msg.include?("around") || msg.include?("below")
        price_match = msg.match(/(\d+)/)
        if price_match
          max_price = price_match[1].to_i
          affordable = grounds.select { |g| g.price_per_hour <= max_price }
          if affordable.any?
            response = "Grounds under ₹#{max_price}:\n"
            affordable.each do |g|
              response += "• #{g.name}: ₹#{g.price_per_hour}/hour, #{g.location}\n"
            end
            return response
          else
            cheapest = grounds.min_by(&:price_per_hour)
            return "No grounds under ₹#{max_price}. The cheapest ground is #{cheapest.name} at ₹#{cheapest.price_per_hour}/hour in #{cheapest.location}."
          end
        end
      end
      
      # Check for cheapest ground
      if msg.include?("cheapest") || (msg.include?("best") && msg.include?("price"))
        cheapest = grounds.min_by(&:price_per_hour)
        return "The cheapest ground is #{cheapest.name} at ₹#{cheapest.price_per_hour}/hour in #{cheapest.location}."
      end
      
      # Check for specific location
      locations = ["bangalore", "btm", "varthur", "sarjapura", "whitefield", "indiranagar", "koramangala"]
      locations.each do |loc|
        if msg.include?(loc)
          location_grounds = grounds.select { |g| g.location.downcase.include?(loc) }
          if location_grounds.any?
            response = "Grounds in #{loc.capitalize}:\n"
            location_grounds.each do |g|
              response += "• #{g.name}: ₹#{g.price_per_hour}/hour\n"
            end
            return response
          end
        end
      end
      
      # Default recommendation - top 3 grounds
      top_grounds = grounds.first(3)
      response = "Here are top grounds near you:\n"
      top_grounds.each do |g|
        response += "• #{g.name}: ₹#{g.price_per_hour}/hour, #{g.location}\n"
      end
      response
    else
      "No grounds available yet. Check back soon!"
    end
  end
end