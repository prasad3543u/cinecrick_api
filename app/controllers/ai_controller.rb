class AiController < ApplicationController
  def chat
    message = params[:message]
    
    if message.blank?
      return render json: { error: "Message is required" }, status: :unprocessable_entity
    end

    response = generate_response(message.downcase)
    render json: { response: response }, status: :ok
  end

  private

  def generate_response(message)
    # Ground related questions
    if message.include?("ground") && (message.include?("recommend") || message.include?("near"))
      return "We have #{Ground.count} cricket grounds available! Check the Grounds page to explore options. Popular ones include ARL Cricket Ground and Lakshmi Cricket Ground."
    end
    
    if message.include?("ground") && message.include?("available")
      return "You can view all grounds on the Grounds page. Select a date to see available slots for that ground."
    end

    # Booking related questions
    if message.include?("book") && (message.include?("how") || message.include?("slot"))
      return "To book a slot:\n1. Go to Grounds page\n2. Select a ground\n3. Pick a date\n4. Choose a time slot\n5. Select match type (With/Without Opponents)\n6. Click 'Book Now'\nYou'll get a WhatsApp confirmation!"
    end

    if message.include?("cancel") || message.include?("refund")
      return "Cancellation Policy:\n• Cancel more than 3 days before match: 100% refund\n• Cancel between 2-3 days before: 25% refund\n• Cancel within 48 hours: No refund\nYou can cancel from My Bookings page."
    end

    # Price related questions
    if message.include?("price") || message.include?("cost")
      return "Prices vary by day and time:\n• Weekdays: ₹2500 per slot\n• Weekends & Holidays: ₹3000-4000 per slot\n• Without Opponents (full ground): 2x price"
    end

    # Timing related questions
    if message.include?("time") || message.include?("slot") && message.include?("available")
      return "Slots available daily:\n• Morning: 06:30 - 09:30\n• Mid-Day: 09:30 - 12:30\n• Evening: 13:00 - 18:00"
    end

    # About CrickOps
    if message.include?("crickops") || (message.include?("about") && message.include?("platform"))
      return "CrickOps is a complete cricket ground management platform. Features:\n• Book cricket grounds instantly\n• View available time slots\n• Manage umpires and groundsmen\n• Get WhatsApp confirmations\n• Track match day status\n• Auto reminders 12 hours before match"
    end

    # Welcome / Greeting
    if message.include?("hi") || message.include?("hello") || message.include?("hey")
      return "Hello! I'm your CricketOps assistant. I can help you with:\n• Finding grounds\n• Booking slots\n• Cancellation policy\n• Pricing information\n• Platform features\nWhat would you like to know?"
    end

    # Default response
    "I'm here to help! You can ask me about:\n• Finding cricket grounds\n• How to book a slot\n• Cancellation policy\n• Prices and timings\n• Platform features\nWhat would you like to know?"
  end
end