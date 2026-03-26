require 'httparty'

class HuggingFaceService
  def initialize
    @api_key = ENV['HF_API_KEY']
  end

  def chat(message, user_context = {})
    # Check if API key exists
    if @api_key.blank?
      return "Hugging Face API key not configured. Please add HF_API_KEY in Render environment variables."
    end

    # Get real data from your database
    grounds_data = get_grounds_data
    bookings_data = get_bookings_data
    
    # Build the prompt with real data
    prompt = <<~PROMPT
      You are CrickOps AI Assistant. Answer using ONLY the REAL DATA below.

      REAL GROUNDS DATA:
      #{grounds_data}

      REAL BOOKINGS DATA:
      #{bookings_data}

      CANCELLATION POLICY:
      - Cancel >3 days before match: 100% refund
      - Cancel 2-3 days before: 25% refund
      - Cancel <48 hours: No refund

      PRICING:
      - Weekdays: ₹2500 per slot
      - Weekends: ₹3000-4000 per slot
      - Without Opponents: 2x price

      USER QUESTION: "#{message}"

      RULES:
      1. Use ONLY the REAL DATA above.
      2. Be friendly and helpful.

      YOUR RESPONSE:
    PROMPT

    # NEW: Use the correct Hugging Face API URL
    url = "https://router.huggingface.co/hf-inference/models/google/flan-t5-small"
    
    begin
      response = HTTParty.post(
        url,
        headers: {
          "Authorization" => "Bearer #{@api_key}",
          "Content-Type" => "application/json"
        },
        body: { inputs: prompt }.to_json,
        timeout: 15
      )

      if response.code == 200
        result = response.parsed_response
        if result.is_a?(Array) && result[0].present?
          ai_response = result[0]["generated_text"]
          return ai_response if ai_response.present?
        elsif result.is_a?(String)
          return result
        else
          return "I couldn't generate a response. Please try again."
        end
      else
        return "Hugging Face API error: #{response.code}. Please try again later."
      end
    rescue => e
      return "Error: #{e.message}. Please try again."
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
end