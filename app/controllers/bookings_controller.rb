
class BookingsController < ApplicationController
  before_action :authorize_request

  # GET /bookings
  def index
    bookings = current_user.bookings.includes(:ground, :slot)

    render json: bookings.as_json(
      include: {
        ground: {},
        slot: {}
      }
    ), status: :ok
  end

  # POST /bookings
  def create
    slot = Slot.find_by(id: params[:slot_id])
    return render json: { error: "Slot not found" }, status: :not_found unless slot

    if slot.status != "available"
      return render json: { error: "Slot is not available" }, status: :unprocessable_entity
    end

    booking = Booking.new(
      user: current_user,
      ground_id: params[:ground_id],
      slot_id: params[:slot_id],
      booking_date: params[:booking_date],
      total_price: params[:total_price],
      status: "confirmed",
      payment_status: "pending"
    )

    if booking.save
      slot.update(status: "booked")
      render json: booking.as_json(include: [:ground, :slot]), status: :created
    else
      render json: { errors: booking.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def authorize_request
    header = request.headers["Authorization"]
    return render json: { error: "Unauthorized" }, status: :unauthorized unless header

    token = header.split(" ").last
    decoded = JsonWebToken.decode(token)
    return render json: { error: "Unauthorized" }, status: :unauthorized unless decoded && decoded[:user_id]

    @current_user = User.find_by(id: decoded[:user_id])
    return render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def current_user
    @current_user
  end
end