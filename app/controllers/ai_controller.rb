class AiController < ApplicationController
  def chat
    message = params[:message]
    
    if message.blank?
      return render json: { error: "Message is required" }, status: :unprocessable_entity
    end

    user_context = {
      role: current_user&.role,
      bookings_count: current_user&.bookings&.count || 0
    }

    begin
      ai_service = GeminiAiService.new
      response = ai_service.chat(message, user_context)
      render json: { response: response }, status: :ok
    rescue => e
      Rails.logger.error "AI Error: #{e.message}"
      render json: { response: smart_fallback(message) }, status: :ok
    end
  end

  private

  def smart_fallback(message)
    msg = message.downcase
    grounds = Ground.all
    
    # Price-based query
    if msg.include?("under") || msg.include?("around")
      price_match = msg.match(/(\d+)/)
      if price_match && grounds.any?
        max_price = price_match[1].to_i
        affordable = grounds.select { |g| g.price_per_hour <= max_price }
        if affordable.any?
          response = "Grounds under ₹#{max_price}:\n"
          affordable.each { |g| response += "• #{g.name}: ₹#{g.price_per_hour}/hour at #{g.location}\n" }
          return response
        else
          cheapest = grounds.min_by(&:price_per_hour)
          return "No grounds under ₹#{max_price}. Cheapest is #{cheapest.name} at ₹#{cheapest.price_per_hour}/hour."
        end
      end
    end
    
    # Cheapest ground
    if msg.include?("cheapest") && grounds.any?
      cheapest = grounds.min_by(&:price_per_hour)
      return "Cheapest ground: #{cheapest.name} at ₹#{cheapest.price_per_hour}/hour in #{cheapest.location}."
    end
    
    # General response with real data
    if grounds.any?
      "We have #{grounds.count} grounds. Prices: ₹#{grounds.minimum(:price_per_hour)} - ₹#{grounds.maximum(:price_per_hour)}/hour. What's your budget or location?"
    else
      "No grounds yet. Check back soon!"
    end
  end
end