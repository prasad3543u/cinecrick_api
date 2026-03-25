# app/controllers/ai_controller.rb
class AIController < ApplicationController
  before_action :authenticate_request
  skip_before_action :verify_authenticity_token

  def chat
    message = params[:message]
    ai = GeminiAIService.new
    response = ai.chat(message, { user: current_user.email })
    
    render json: { response: response }, status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end