require 'httparty'

class OpenrouterAiService
  API_URL = "https://openrouter.ai/api/v1/chat/completions"

  def initialize
    @api_key = ENV['OPENROUTER_API_KEY']
    @site_url = ENV['SITE_URL'] || "https://cinecrick-spa.vercel.app"
    @site_name = "CrickOps"
  end

  def chat(message, user_context = {})
    if @api_key.blank?
      return "OpenRouter API key not configured. Please add OPENROUTER_API_KEY in Render."
    end

    grounds_data = get_grounds_data
    bookings_data = get_bookings_data
    user_data = get_user_data(user_context)

    system_prompt = <<~PROMPT
      You are CrickOps AI Assistant, a helpful cricket ground booking assistant.

      REAL DATA FROM DATABASE:

      GROUNDS AVAILABLE:
      #{grounds_data}

      BOOKINGS STATISTICS:
      #{bookings_data}

      USER CONTEXT:
      #{user_data}

      CANCELLATION POLICY:
      - Cancel more than 3 days before match: 100% refund
      - Cancel between 2-3 days before match: 25% refund
      - Cancel within 48 hours of match: No refund

      PRICING:
      - Weekdays (Monday-Friday): Rs. 2500 per 3-hour slot
      - Weekends (Saturday-Sunday):
        * Morning (6:30-9:30): Rs. 4000
        * Mid-Day (9:30-12:30): Rs. 3500
        * Evening (13:00-18:00): Rs. 3000
      - Without Opponents (full ground): 2x price

      SLOT TIMINGS:
      - Morning: 06:30 AM - 09:30 AM
      - Mid-Day: 09:30 AM - 12:30 PM
      - Evening: 01:00 PM - 06:00 PM

      RULES:
      1. Use ONLY the REAL DATA above. Never make up data.
      2. If asked about grounds, mention specific names, prices, and locations.
      3. If asked about cheapest ground, find the lowest price from the data.
      4. If asked about grounds in a location, filter by location.
      5. Be friendly, helpful, and conversational.
    PROMPT

    # Try multiple free models in order
    models = [
      "meta-llama/llama-3.2-3b-instruct:free",
      "microsoft/phi-3-mini-128k-instruct:free",
      "mistralai/mistral-7b-instruct:free",
      "google/gemini-2.0-flash-lite-preview-02-05:free"
    ]
    
    models.each do |model|
      response = make_api_call(model, system_prompt, message)
      return response if response
    end
    
    return "All AI models are currently unavailable. Please try again later."
  rescue => e
    return "Error: #{e.message}"
  end

  private

  def make_api_call(model, system_prompt, user_message)
    response = HTTParty.post(
      API_URL,
      headers: {
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type" => "application/json",
        "HTTP-Referer" => @site_url,
        "X-Title" => @site_name
      },
      body: {
        model: model,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_message }
        ],
        temperature: 0.7,
        max_tokens: 500
      }.to_json,
      timeout: 30
    )

    if response.code == 200
      result = response.parsed_response
      if result["choices"] && result["choices"][0]
        return result["choices"][0]["message"]["content"]
      end
    elsif response.code == 404
      # Model not found, try next
      return nil
    end
    nil
  rescue
    nil
  end

  def get_grounds_data
    grounds = Ground.all
    if grounds.any?
      grounds.map do |g|
        "- #{g.name}: Rs. #{g.price_per_hour}/hour, Location: #{g.location}, Timings: #{g.opening_time} - #{g.closing_time}"
      end.join("\n")
    else
      "No grounds added yet."
    end
  end

  def get_bookings_data
    total = Booking.count
    confirmed = Booking.where(status: "confirmed").count
    pending = Booking.where(status: "pending").count
    "Total Bookings: #{total}, Confirmed: #{confirmed}, Pending: #{pending}"
  end

  def get_user_data(user_context)
    role = user_context[:role] || 'User'
    bookings_count = user_context[:bookings_count] || 0
    "Role: #{role}, Your Bookings: #{bookings_count}"
  end
end