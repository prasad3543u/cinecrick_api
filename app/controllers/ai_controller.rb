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
      # Use Hugging Face AI
      ai_service = HuggingFaceService.new
      response = ai_service.chat(message, user_context)
      render json: { response: response }, status: :ok
    rescue => e
      render json: { response: "Error: #{e.message}" }, status: :ok
    end
  end
end