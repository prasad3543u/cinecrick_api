# app/services/gemini_ai_service.rb
require 'httparty'

class GeminiAIService
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"

  def initialize
    @api_key = ENV['GEMINI_API_KEY']
  end

  def chat(message, user_context = {})
    prompt = <<~PROMPT
      You are CrickOps AI Assistant. Help users with cricket ground booking.

      User Message: #{message}
      
      Respond helpfully and concisely.
    PROMPT

    response = HTTParty.post(
      "#{API_URL}?key=#{@api_key}",
      headers: { "Content-Type" => "application/json" },
      body: {
        contents: [{
          parts: [{ text: prompt }]
        }]
      }.to_json
    )

    if response.success?
      response.dig("candidates", 0, "content", "parts", 0, "text") || "I'm here to help!"
    else
      "I'm having trouble connecting. Please try again."
    end
  rescue => e
    "Sorry, I couldn't process that. Please try again."
  end
end