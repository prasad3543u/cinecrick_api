class Admin::OfflineBookingsController < ApplicationController
  before_action :authenticate_request
  before_action :authorize_admin

  # GET /admin/offline_bookings/new (optional, not strictly needed)
  def new
    render json: { grounds: Ground.all }
  end

  # POST /admin/offline_bookings
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
        total_price: user_data[:payment_amount],
        status: "confirmed",
        payment_status: user_data[:payment_status] == "paid" ? "paid" : "pending"
      )

      if booking.save
        # Payment record
        PaymentBooking.create(
          booking_id: booking.id,
          amount: booking.total_price,
          status: user_data[:payment_status],
          payment_date: user_data[:payment_status] == "paid" ? Date.today : nil,
          notes: "Offline booking by admin"
        )

        # Umpire payment if provided
        if params[:umpire_paid].present?
          StaffPayment.create(
            booking_id: booking.id,
            staff_type: "umpire",
            name: params[:umpire_name] || "Umpire",
            amount: params[:umpire_amount] || 0,
            status: params[:umpire_paid],
            paid_date: params[:umpire_paid] == "paid" ? Date.today : nil
          )
        end

        bookings << booking
      else
        return render json: { errors: booking.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # Update slot occupancy
    slot.update!(teams_booked_count: slot.teams_booked_count + users.size)
    if slot.teams_booked_count >= slot.max_teams
      slot.update!(status: "booked")
    end

    render json: { bookings: bookings, message: "Offline booking(s) created successfully" }, status: :created
  end

  private

  def authorize_admin
    render json: { error: "Unauthorized" }, status: :unauthorized unless current_user&.role == 'admin'
  end
end