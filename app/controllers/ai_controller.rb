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
      render json: { response: fallback_response(message) }, status: :ok
    end
  end

  private

  def fallback_response(message)
    msg = message.downcase
    if msg.include?("ground")
      "We have #{Ground.count} cricket grounds available! Check the Grounds page to explore."
    elsif msg.include?("cancel")
      "You can cancel up to 48 hours before match. 100% refund >3 days, 25% refund 2-3 days."
    else
      "I'm here to help! Ask me about grounds, bookings, prices, or cancellations."
    end
  end
end