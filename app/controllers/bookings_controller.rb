class BookingsController < ApplicationController
  before_action :authenticate_request

  def index
    bookings = current_user.bookings.includes(:ground, :slot).order(created_at: :desc)
    render json: bookings.as_json(include: [:ground, :slot]), status: :ok
  end
  
  def create
  slot = Slot.find(params[:slot_id])
  match_type = params[:match_type]

  unless ["with_opponents", "without_opponents"].include?(match_type)
    return render json: { error: "Invalid match type" }, status: :unprocessable_entity
  end

  if slot.status == "booked" || slot.status == "pending"
    return render json: { error: "This slot is already booked" }, status: :unprocessable_entity
  end

  # Calculate price based on match type
  total_price = if match_type == "without_opponents"
    slot.price * 2  # paying for both team slots
  else
    slot.price      # paying for one team slot
  end

  booking = current_user.bookings.new(booking_params)
  booking.ground_id = slot.ground_id
  booking.booking_date = slot.slot_date
  booking.total_price = total_price
  booking.match_type = match_type
  booking.payment_status = "pending"
  booking.status = "pending"

  ActiveRecord::Base.transaction do
    booking.save!

    if match_type == "without_opponents"
      # Books entire ground — both team slots taken
      slot.update!(teams_booked_count: 2, status: "pending")
    else
      current_count = slot.teams_booked_count || 0
      new_count = current_count + 1

      if new_count >= 2
        slot.update!(teams_booked_count: 2, status: "pending")
      else
        slot.update!(teams_booked_count: 1, status: "available")
      end
    end
  end

  render json: booking.as_json(include: [:ground, :slot]), status: :created
rescue => e
  render json: { error: e.message }, status: :unprocessable_entity
end

  def confirm
  booking = Booking.includes(:slot, :ground).find(params[:id])
  booking.update!(status: "confirmed")
  booking.slot.update!(status: "booked")
  render json: booking.as_json(include: [:ground, :slot]), status: :ok
rescue => e
  render json: { error: e.message }, status: :unprocessable_entity
end

def cancel
  booking = Booking.includes(:slot, :ground).find(params[:id])
  booking.update!(status: "cancelled")
  booking.slot.update!(
    status: "available",
    teams_booked_count: [0, (booking.slot.teams_booked_count || 1) - 1].max
  )
  render json: booking.as_json(include: [:ground, :slot]), status: :ok
rescue => e
  render json: { error: e.message }, status: :unprocessable_entity
end

  def admin_index
  bookings = Booking.includes(:ground, :slot, :user).order(created_at: :desc)
  render json: bookings.as_json(include: [:ground, :slot, :user]), status: :ok
end
  
  private

  def booking_params
    params.permit(:slot_id, :ground_id, :booking_date, :total_price, :match_type)
  end
end