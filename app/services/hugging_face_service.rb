require 'httparty'

class HuggingFaceService
  def initialize
    @api_key = ENV['HF_API_KEY']
  end

  def chat(message, user_context = {})
    # Get real data from database for context
    grounds_data = get_grounds_data
    bookings_data = get_bookings_data
    
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
      - Weekdays (Mon-Fri): ₹2500 per 3-hour slot
      - Weekends (Sat-Sun): Morning ₹4000, Mid-Day ₹3500, Evening ₹3000
      - Without Opponents: 2x price

      SLOT TIMINGS:
      - Morning: 06:30 AM - 09:30 AM
      - Mid-Day: 09:30 AM - 12:30 PM
      - Evening: 01:00 PM - 06:00 PM

      USER QUESTION: "#{message}"

      RULES:
      1. Use ONLY the REAL DATA above. Never make up data.
      2. If asked about grounds, mention specific names, prices, locations.
      3. If asked about cheapest, find from the data.
      4. Be friendly and conversational.

      YOUR RESPONSE:
    PROMPT

    # Try Gemini first
    gemini_response = try_gemini(prompt)
    return gemini_response if gemini_response.present?
    
    # Try Hugging Face second
    hf_response = try_huggingface(prompt)
    return hf_response if hf_response.present?
    
    # If both fail
    "I'm having trouble connecting. Please try again later."
  end

  private

  def try_gemini(prompt)
    api_key = ENV['GEMINI_API_KEY']
    return nil if api_key.blank?
    
    url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-001:generateContent?key=#{api_key}"
    
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
      result.dig("candidates", 0, "content", "parts", 0, "text")
    else
      nil
    end
  rescue => e
    Rails.logger.error "Gemini Error: #{e.message}"
    nil
  end

  def try_huggingface(prompt)
    api_key = ENV['HF_API_KEY']
    model = "microsoft/DialoGPT-medium"
    url = "https://api-inference.huggingface.co/models/#{model}"
    
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{api_key}" if api_key.present?
    
    response = HTTParty.post(
      url,
      headers: headers,
      body: { inputs: prompt }.to_json,
      timeout: 10
    )
    
    if response.success?
      result = response.parsed_response
      if result.is_a?(Array) && result[0].present?
        ai_response = result[0]["generated_text"]
        if ai_response.include?("YOUR RESPONSE:")
          ai_response = ai_response.split("YOUR RESPONSE:").last.strip
        end
        return ai_response
      end
    end
    nil
  rescue => e
    Rails.logger.error "HuggingFace Error: #{e.message}"
    nil
  end

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