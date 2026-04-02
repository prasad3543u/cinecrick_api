class AiController < ApplicationController
  before_action :authenticate_request

  def chat
    message = params[:message]
    history = params[:history] || []

    if message.blank?
      return render json: { error: "Message is required" }, status: :unprocessable_entity
    end

    response = AdvancedAiService.new.chat(message, history)
    render json: { response: response }, status: :ok
  rescue => e
    render json: { error: "AI service unavailable. Please try again." }, status: :ok
  end
end