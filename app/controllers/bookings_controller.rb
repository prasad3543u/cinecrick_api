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

    total_price = if match_type == "without_opponents"
      slot.price * 2
    else
      slot.price
    end

    booking = current_user.bookings.new(booking_params)
    booking.ground_id    = slot.ground_id
    booking.booking_date = slot.slot_date
    booking.total_price  = total_price
    booking.match_type   = match_type
    booking.payment_status = "pending"
    booking.status         = "pending"

    ActiveRecord::Base.transaction do
      booking.save!
      if match_type == "without_opponents"
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

  # Admin assigns umpire + groundsman to a confirmed booking
  def assign_staff
    booking = Booking.find(params[:id])
    booking.update!(
      umpire_name:      params[:umpire_name],
      umpire_phone:     params[:umpire_phone],
      groundsman_name:  params[:groundsman_name],
      groundsman_phone: params[:groundsman_phone]
    )
    render json: booking.as_json(include: [:ground, :slot, :user]), status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Admin updates match day status checkboxes
  def update_status
    booking = Booking.find(params[:id])
    booking.update!(
      umpire_reached:  params[:umpire_reached],
      water_arranged:  params[:water_arranged],
      balls_ready:     params[:balls_ready],
      ground_ready:    params[:ground_ready]
    )
    render json: booking.as_json(include: [:ground, :slot, :user]), status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def admin_index
    bookings = Booking.includes(:ground, :slot, :user).order(created_at: :desc)
    render json: bookings.as_json(include: [:ground, :slot, :user]), status: :ok
  end

  # Today's confirmed bookings for match day dashboard
  def today
    today = Date.today.to_s
    bookings = Booking.includes(:ground, :slot, :user)
      .where(booking_date: today, status: "confirmed")
      .order("slots.start_time ASC")
    render json: bookings.as_json(include: [:ground, :slot, :user]), status: :ok
  end

  private

  def booking_params
    params.permit(:slot_id, :ground_id, :booking_date, :total_price, :match_type)
  end
end