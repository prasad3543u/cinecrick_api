# app/controllers/ai_controller.rb
class AIController < ApplicationController
  skip_before_action :authenticate_request, only: [:chat]

  def chat
    message = params[:message]
    
    if message.blank?
      return render json: { error: "Message is required" }, status: :unprocessable_entity
    end

    # Simple response (will be replaced with Gemini later)
    response = "I'm your CrickOps assistant! I can help you find cricket grounds, check availability, and answer booking questions. How can I help you today?"

    render json: { response: response }, status: :ok
  end
end