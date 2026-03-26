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
      # Use Hugging Face AI (free)
      ai_service = HuggingFaceService.new
      response = ai_service.chat(message, user_context)
      render json: { response: response }, status: :ok
    rescue => e
      Rails.logger.error "AI Error: #{e.message}"
      render json: { response: fallback_response(message) }, status: :ok
    end
  end

  private

  def fallback_response(message)
    msg = message.downcase
    grounds = Ground.all
    
    if msg.include?("book")
      "To book a slot: Go to Grounds → Select ground → Pick date/time → Click 'Book Now'"
    elsif msg.include?("cancel")
      "Cancel up to 48 hours before match. 100% refund >3 days, 25% refund 2-3 days."
    elsif msg.include?("price") && grounds.any?
      "Prices range from ₹#{grounds.minimum(:price_per_hour)} to ₹#{grounds.maximum(:price_per_hour)}/hour"
    else
      "I'm your CrickOps assistant! I can help with bookings, cancellations, and finding grounds."
    end
  end
end