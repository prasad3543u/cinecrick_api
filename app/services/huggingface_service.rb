require 'httparty'

class HuggingFaceService
  def initialize
    # Free - no API key needed for some models
    @api_key = ENV['HF_API_KEY']  # Optional
  end

  def chat(message, user_context = {})
    # Use free model (no API key required)
    model = "microsoft/DialoGPT-small"  # Free, no key needed
    
    url = "https://api-inference.huggingface.co/models/#{model}"
    
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{@api_key}" if @api_key.present?
    
    begin
      response = HTTParty.post(
        url,
        headers: headers,
        body: { inputs: message }.to_json,
        timeout: 10
      )

      if response.success?
        result = response.parsed_response
        if result.is_a?(Array) && result[0].present?
          ai_response = result[0]["generated_text"]
          return ai_response if ai_response.present?
        end
      end
    rescue => e
      Rails.logger.error "HuggingFace Error: #{e.message}"
    end
    
    # Fallback to smart responses
    smart_fallback(message)
  end

  private

  def smart_fallback(message)
    msg = message.downcase
    grounds = Ground.all
    
    # Booking help
    if msg.include?("book a slot") || msg.include?("how to book")
      return <<~RESPONSE
        To book a slot:
        1. Go to the Grounds page
        2. Select a cricket ground
        3. Choose a date from the calendar
        4. Pick an available time slot
        5. Select match type
        6. Click "Book Now"
        
        You'll get a WhatsApp confirmation!
      RESPONSE
    end
    
    # Cancellation policy
    if msg.include?("cancel") || msg.include?("refund")
      return <<~RESPONSE
        Cancellation Policy:
        • Cancel >3 days before match: 100% refund
        • Cancel 2-3 days before: 25% refund
        • Cancel <48 hours: No refund
      RESPONSE
    end
    
    # Pricing
    if msg.include?("price") || msg.include?("cost")
      return <<~RESPONSE
        Pricing:
        • Weekdays: ₹2500 per slot
        • Weekends: ₹3000-4000 per slot
        • Without Opponents: 2x price
      RESPONSE
    end
    
    # Ground recommendations
    if msg.include?("ground") && grounds.any?
      top_grounds = grounds.first(3)
      response = "Here are top grounds:\n"
      top_grounds.each do |g|
        response += "• #{g.name}: ₹#{g.price_per_hour}/hour, #{g.location}\n"
      end
      return response
    end
    
    # Greeting
    if msg.include?("hi") || msg.include?("hello")
      return "Hello! I'm your CrickOps assistant. How can I help you today?"
    end
    
    # Default
    "I'm your CrickOps assistant! I can help with bookings, cancellations, pricing, and finding grounds. What would you like to know?"
  end
end