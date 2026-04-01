class Admin::OfflineBookingsController < ApplicationController
  before_action :authenticate_request
  before_action :authorize_admin

  def create
    ground = Ground.find(params[:ground_id])
    slot = Slot.find(params[:slot_id])

    available = slot.max_teams - slot.teams_booked_count
    users = params[:users] || []

    if params[:match_type] == "with_opponents"
      if users.size != 2
        return render json: { error: "With opponents requires exactly 2 teams" }, status: :unprocessable_entity
      end
      if available < 2
        return render json: { error: "Slot does not have capacity for 2 teams" }, status: :unprocessable_entity
      end
    else
      if users.size != 1
        return render json: { error: "Without opponents requires exactly 1 team" }, status: :unprocessable_entity
      end
      if available < 1
        return render json: { error: "Slot is already fully booked" }, status: :unprocessable_entity
      end
    end

    bookings = []

    ActiveRecord::Base.transaction do
      users.each do |user_data|
        # Find or create user
        user = User.find_or_create_by(email: user_data[:email]) do |u|
          u.name = user_data[:name]
          u.phone = user_data[:phone]
          u.password = SecureRandom.hex(8)
          u.password_confirmation = u.password
          u.role = 'user'
        end

        booking = Booking.new(
          user_id: user.id,
          ground_id: ground.id,
          slot_id: slot.id,
          booking_date: params[:booking_date],
          match_type: params[:match_type],
          total_price: 0,                # No payment tracked here
          status: "confirmed",
          payment_status: "pending"       # No payment recorded
        )

        booking.save!
        bookings << booking
      end

      # Update slot occupancy
      slot.update!(teams_booked_count: slot.teams_booked_count + users.size)
      if slot.teams_booked_count >= slot.max_teams
        slot.update!(status: "booked")
      end
    end

    render json: { bookings: bookings, message: "Offline booking(s) created successfully" }, status: :created
  end

  private

  def authorize_admin
    render json: { error: "Unauthorized" }, status: :unauthorized unless current_user&.role == 'admin'
  end
end