require 'httparty'

class GeminiAiService
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"

  def initialize
    @api_key = ENV['GEMINI_API_KEY']
  end

  def chat(message, user_context = {})
    return fallback_response(message) if @api_key.blank?

    prompt = build_prompt(message, user_context)
    
    begin
      response = HTTParty.post(
        "#{API_URL}?key=#{@api_key}",
        headers: { "Content-Type" => "application/json" },
        body: {
          contents: [{
            parts: [{ text: prompt }]
          }],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 500,
            topP: 0.95
          }
        }.to_json
      )

      if response.success?
        result = response.parsed_response
        result.dig("candidates", 0, "content", "parts", 0, "text") || fallback_response(message)
      else
        Rails.logger.error "Gemini API Error: #{response.body}"
        fallback_response(message)
      end
    rescue => e
      Rails.logger.error "Gemini Error: #{e.message}"
      fallback_response(message)
    end
  end

  private

  def build_prompt(message, user_context)
    grounds_info = Ground.limit(5).map do |g|
      "- #{g.name}: ₹#{g.price_per_hour}/hour, Location: #{g.location}"
    end.join("\n")

    <<~PROMPT
      You are CrickOps AI Assistant, a helpful cricket ground booking assistant.

      PLATFORM INFO:
      - Available Grounds: #{Ground.count} grounds
      #{grounds_info}
      - Booking Policy: 100% refund >3 days before match, 25% refund 2-3 days before, 0% <48hrs
      - Slot Timings: Morning (06:30-09:30), Mid-Day (09:30-12:30), Evening (13:00-18:00)
      - Pricing: Weekdays ₹2500 per slot, Weekends ₹3000-4000 per slot
      - Match Types: With Opponents (need another team), Without Opponents (full ground, 2x price)
      - Total Bookings: #{Booking.count}

      USER CONTEXT:
      - Role: #{user_context[:role] || 'User'}
      - Past Bookings: #{user_context[:bookings_count] || 0}

      USER MESSAGE: "#{message}"

      Respond helpfully, concisely, and in a friendly tone. Keep responses under 200 words.
      If recommending grounds, mention specific names and prices.
      Be helpful with booking steps if asked.
    PROMPT
  end

  def fallback_response(message)
    msg = message.downcase
    if msg.include?("ground") && (msg.include?("recommend") || msg.include?("near"))
      "We have #{Ground.count} cricket grounds available! Popular ones include:\n• ARL Cricket Ground - ₹2500/hour\n• Lakshmi Cricket Ground - ₹2000/hour\nCheck the Grounds page to explore all options!"
    elsif msg.include?("book") && (msg.include?("how") || msg.include?("slot"))
      "To book a slot:\n1. Go to Grounds page\n2. Select a ground\n3. Pick a date\n4. Choose a time slot\n5. Select match type\n6. Click 'Book Now'\nYou'll get a WhatsApp confirmation!"
    elsif msg.include?("cancel") || msg.include?("refund")
      "Cancellation Policy:\n• Cancel >3 days before match: 100% refund\n• Cancel 2-3 days before: 25% refund\n• Cancel <48 hours: No refund"
    elsif msg.include?("price") || msg.include?("cost")
      "Prices:\n• Weekdays: ₹2500 per slot\n• Weekends: ₹3000-4000 per slot\n• Without Opponents: 2x price"
    else
      "I'm your CrickOps assistant! I can help with finding grounds, booking slots, cancellation policy, pricing, and platform features. What would you like to know?"
    end
  end
end