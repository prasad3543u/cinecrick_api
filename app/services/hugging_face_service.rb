require 'httparty'

class HuggingFaceService
  def initialize
    @api_key = ENV['HF_API_KEY']
  end

  def chat(message, user_context = {})
    # Use free model (no API key required for some)
    model = "microsoft/DialoGPT-small"
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
    
    # Fallback
    smart_fallback(message)
  end

  private

  def smart_fallback(message)
    msg = message.downcase
    grounds = Ground.all
    
    if msg.include?("book a slot") || msg.include?("how to book")
      return "To book a slot: Go to Grounds → Select ground → Pick date/time → Click 'Book Now'"
    elsif msg.include?("cancel") || msg.include?("refund")
      return "Cancel >3 days: 100% refund, 2-3 days: 25% refund, <48h: no refund"
    elsif msg.include?("price") && grounds.any?
      return "Prices range from ₹#{grounds.minimum(:price_per_hour)} to ₹#{grounds.maximum(:price_per_hour)}/hour"
    elsif msg.include?("ground") && grounds.any?
      top = grounds.first(3)
      return "Top grounds:\n" + top.map { |g| "• #{g.name}: ₹#{g.price_per_hour}/hour, #{g.location}" }.join("\n")
    else
      return "I'm your CrickOps assistant! I can help with bookings, cancellations, pricing, and finding grounds."
    end
  end
end