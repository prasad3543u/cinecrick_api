require 'httparty'

class HuggingFaceService
  def initialize
    @api_key = ENV['GEMINI_API_KEY']
  end

  def chat(message, user_context = {})
    if @api_key.blank?
      return "Gemini API key not configured. Please add GEMINI_API_KEY in Render."
    end

    # Get real data from database
    grounds_data = get_grounds_data
    bookings_data = get_bookings_data
    
    prompt = <<~PROMPT
      You are CrickOps AI Assistant. Answer based on REAL DATA below.

      GROUNDS:
      #{grounds_data}

      BOOKINGS:
      #{bookings_data}

      CANCELLATION: Cancel >3 days: 100% refund. 2-3 days: 25% refund. <48h: no refund.
      PRICING: Weekdays ₹2500, Weekends ₹3000-4000, Without Opponents: 2x price.

      USER: "#{message}"

      Answer concisely using only the data above:
    PROMPT

    url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-001:generateContent?key=#{@api_key}"
    
    response = HTTParty.post(
      url,
      headers: { "Content-Type" => "application/json" },
      body: {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.7, maxOutputTokens: 500 }
      }.to_json
    )

    if response.success?
      result = response.parsed_response
      ai_response = result.dig("candidates", 0, "content", "parts", 0, "text")
      return ai_response if ai_response.present?
    end
    
    "Gemini API error. Please try again later."
  end

  private

  def get_grounds_data
    grounds = Ground.all
    if grounds.any?
      grounds.map { |g| "- #{g.name}: ₹#{g.price_per_hour}/hour, #{g.location}" }.join("\n")
    else
      "No grounds yet."
    end
  end

  def get_bookings_data
    "Total: #{Booking.count}, Confirmed: #{Booking.where(status: 'confirmed').count}"
  end
end
