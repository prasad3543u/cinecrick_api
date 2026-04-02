class AiController < ApplicationController
  skip_before_action :authenticate_request, only: [:chat]

  def chat
    message = params[:message]

    if message.blank?
      return render json: { error: "Message is required" }, status: :unprocessable_entity
    end

    ai_service = AdvancedAiService.new
    response = ai_service.chat(message)

    render json: { response: response }, status: :ok
  rescue => e
    Rails.logger.error "AI Error: #{e.message}"
    render json: { response: "I'm having trouble. Please try again." }, status: :ok
  end
end