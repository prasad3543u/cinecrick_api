class AiController < ApplicationController
  skip_before_action :authenticate_request, only: [:chat]

  def chat
    message = params[:message]

    if message.blank?
      return render json: { error: "Message is required" }, status: :unprocessable_entity
    end

    response = AdvancedAiService.new.chat(message)

    render json: { response: response }, status: :ok
  end
end