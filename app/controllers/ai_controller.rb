class AiController < ApplicationController
  def chat
    message = params[:message]
    
    if message.blank?
      return render json: { error: "Message is required" }, status: :unprocessable_entity
    end

    user_context = {
      user_id: current_user&.id,
      role: current_user&.role,
      email: current_user&.email,
      bookings_count: current_user&.bookings&.count || 0
    }

    begin
      ai_service = OpenrouterAiService.new
      response = ai_service.chat(message, user_context)
      render json: { response: response }, status: :ok
    rescue => e
      Rails.logger.error "AI Error: #{e.message}"
      render json: { response: "I encountered an error. Please try again." }, status: :ok
    end
  end
end