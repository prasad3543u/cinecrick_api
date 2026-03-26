require 'httparty'

class GeminiAiService
  # Try the stable model first
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"

  def initialize
    @api_key = ENV['GEMINI_API_KEY']
  end

  def chat(message, user_context = {})
    Rails.logger.info "=== GEMINI DEBUG ==="
    Rails.logger.info "API Key present: #{@api_key.present?}"
    Rails.logger.info "API Key starts with AIza: #{@api_key.to_s.start_with?('AIza')}" if @api_key.present?
    
    if @api_key.blank?
      Rails.logger.info "No API key - using fallback"
      return smart_fallback(message)
    end

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
      1. Use ONLY the REAL GROUNDS DATA above.
      2. Be specific with ground names and prices.
      3. Keep response under 150 words.
      4. Be friendly.

      YOUR RESPONSE:
    PROMPT

    begin
      Rails.logger.info "Calling Gemini API..."
      
      response = HTTParty.post(
        "#{API_URL}?key=#{@api_key}",
        headers: { "Content-Type" => "application/json" },
        body: {
          contents: [{
            parts: [{ text: prompt }]
          }]
        }.to_json
      )

      Rails.logger.info "Gemini Response Code: #{response.code}"
      
      if response.success?
        result = response.parsed_response
        ai_response = result.dig("candidates", 0, "content", "parts", 0, "text")
        Rails.logger.info "Gemini Response: #{ai_response}"
        ai_response.present? ? ai_response : smart_fallback(message)
      else
        Rails.logger.error "Gemini API Error: #{response.body}"
        smart_fallback(message)
      end
    rescue => e
      Rails.logger.error "Gemini Error: #{e.message}"
      smart_fallback(message)
    end
  end

  private

  def get_grounds_data
    grounds = Ground.all
    if grounds.any?
      grounds.map do |g|
        "- #{g.name}: ₹#{g.price_per_hour}/hour, Location: #{g.location}"
      end.join("\n")
    else
      "No grounds added yet."
    end
  end

  def get_bookings_data
    total = Booking.count
    confirmed = Booking.where(status: "confirmed").count
    "Total Bookings: #{total}, Confirmed: #{confirmed}"
  end

  def smart_fallback(message)
    # ... your existing smart_fallback code
    grounds = Ground.all
    if grounds.any?
      top_grounds = grounds.first(3)
      response = "Here are top grounds:\n"
      top_grounds.each do |g|
        response += "• #{g.name}: ₹#{g.price_per_hour}/hour, #{g.location}\n"
      end
      response
    else
      "No grounds available yet."
    end
  end
end