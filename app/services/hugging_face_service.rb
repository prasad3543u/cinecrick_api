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
      You are CrickOps AI Assistant, a helpful cricket ground booking assistant.

      REAL DATA FROM DATABASE:
      
      GROUNDS AVAILABLE:
      #{grounds_data}

      BOOKINGS STATISTICS:
      #{bookings_data}

      CANCELLATION POLICY:
      - Cancel more than 3 days before match: 100% refund
      - Cancel between 2-3 days before match: 25% refund
      - Cancel within 48 hours of match: No refund

      PRICING:
      - Weekdays (Monday-Friday): ₹2500 per 3-hour slot
      - Weekends (Saturday-Sunday): 
        • Morning (6:30-9:30): ₹4000
        • Mid-Day (9:30-12:30): ₹3500
        • Evening (13:00-18:00): ₹3000
      - Without Opponents (full ground): 2x price

      SLOT TIMINGS:
      - Morning: 06:30 AM - 09:30 AM
      - Mid-Day: 09:30 AM - 12:30 PM
      - Evening: 01:00 PM - 06:00 PM

      USER QUESTION: "#{message}"

      INSTRUCTIONS:
      1. Use ONLY the REAL DATA above. Never make up data.
      2. If asked about grounds, mention specific names, prices, and locations.
      3. If asked about cheapest ground, find the lowest price from the data.
      4. If asked about grounds in a location, filter by location.
      5. Be friendly, helpful, and conversational.
      6. Keep responses concise but informative.

      YOUR RESPONSE:
    PROMPT

    # Try working models in order
    models = [
      "google/flan-t5-small",
      "facebook/blenderbot-400M-distill"
    ]
    
    models.each do |model|
      url = "https://api-inference.huggingface.co/models/#{model}"
      
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
            # Clean up the response
            if ai_response.include?("YOUR RESPONSE:")
              ai_response = ai_response.split("YOUR RESPONSE:").last.strip
            end
            return ai_response if ai_response.present?
          end
        else
          # Try next model
          next
        end
      rescue => e
        # Error with this model, try next
        next
      end
    end
    
    # If all models fail
    "Hugging Face AI is currently unavailable. Please try again later."
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