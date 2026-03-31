class BookingsController < ApplicationController
  before_action :authenticate_request

  def index
    bookings = current_user.bookings.includes(:ground, :slot).order(created_at: :desc)
    render json: bookings.as_json(include: [:ground, :slot]), status: :ok
  end

  def create
    slot = Slot.lock("FOR UPDATE NOWAIT").find(params[:slot_id])
    match_type = params[:match_type]

    unless ["with_opponents", "without_opponents"].include?(match_type)
      return render json: { error: "Invalid match type" }, status: :unprocessable_entity
    end

    if slot.status == "booked" || slot.status == "pending"
      return render json: { error: "This slot is already booked" }, status: :unprocessable_entity
    end

    if slot.teams_booked_count.to_i >= slot.max_teams.to_i
      return render json: { error: "Slot is already fully booked" }, status: :unprocessable_entity
    end

    total_price = match_type == "without_opponents" ? slot.price * 2 : slot.price

    booking = current_user.bookings.new(booking_params)
    booking.ground_id      = slot.ground_id
    booking.booking_date   = slot.slot_date
    booking.total_price    = total_price
    booking.match_type     = match_type
    booking.payment_status = "pending"
    booking.status         = "pending"

    begin
      ActiveRecord::Base.transaction do
        booking.save!
        case match_type
        when "without_opponents"
          slot.update!(teams_booked_count: slot.max_teams, status: "pending")
        else
          current_count = slot.teams_booked_count || 0
          new_count = current_count + 1
          if new_count >= slot.max_teams
            slot.update!(teams_booked_count: slot.max_teams, status: "pending")
          else
            slot.update!(teams_booked_count: new_count, status: "available")
          end
        end
      end
    rescue ActiveRecord::LockWaitTimeout
      return render json: { error: "Slot is busy. Please try again." }, status: :conflict
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::Deadlocked
      return render json: { error: "This slot was just booked by someone else. Please try another slot." }, status: :conflict
    end

    render json: booking.as_json(include: [:ground, :slot]), status: :created
  rescue ActiveRecord::LockWaitTimeout
    render json: { error: "Slot is currently busy. Please try again in a moment." }, status: :conflict
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def confirm
    booking = Booking.includes(:slot, :ground).find(params[:id])
    unless booking.status == "pending"
      return render json: { error: "Can only confirm pending bookings" }, status: :unprocessable_entity
    end
    ActiveRecord::Base.transaction do
      booking.update!(status: "confirmed")
      booking.slot.update!(status: "booked")
    end
    render json: booking.as_json(include: [:ground, :slot]), status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def cancel
    booking = Booking.includes(:slot, :ground).find(params[:id])
    unless ["pending", "confirmed"].include?(booking.status)
      return render json: { error: "Cannot cancel booking with status: #{booking.status}" }, status: :unprocessable_entity
    end
    if booking.booking_date < Date.today
      return render json: { error: "Cannot cancel past bookings" }, status: :unprocessable_entity
    end
    ActiveRecord::Base.transaction do
      booking.update!(status: "cancelled")
      slot = booking.slot
      other_bookings = Booking.where(slot_id: slot.id)
        .where(status: ["confirmed", "pending"])
        .where.not(id: booking.id).count
      if other_bookings > 0
        slot.update!(
          teams_booked_count: other_bookings,
          status: other_bookings >= slot.max_teams ? "pending" : "available"
        )
      else
        slot.update!(status: "available", teams_booked_count: 0)
      end
    end
    render json: booking.as_json(include: [:ground, :slot]), status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def assign_staff
    booking = Booking.find(params[:id])
    unless booking.status == "confirmed"
      return render json: {
        error: "Staff can only be assigned to confirmed bookings."
      }, status: :unprocessable_entity
    end

    # Phone validation — allow spaces, dashes, +country code
    if params[:umpire_phone].present? &&
        params[:umpire_phone].gsub(/[\s\-]/, "") !~ /\A\+?\d{10,15}\z/
      return render json: { error: "Invalid umpire phone number" }, status: :unprocessable_entity
    end

    if params[:groundsman_phone].present? &&
        params[:groundsman_phone].gsub(/[\s\-]/, "") !~ /\A\+?\d{10,15}\z/
      return render json: { error: "Invalid groundsman phone number" }, status: :unprocessable_entity
    end

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

  def update_status
    booking = Booking.find(params[:id])
    unless booking.status == "confirmed"
      return render json: {
        error: "Status can only be updated for confirmed bookings."
      }, status: :unprocessable_entity
    end

    # Fix: was using umpire_arranged — correct field is umpire_reached
    booking.update!(
      umpire_reached: params.key?(:umpire_reached) ? params[:umpire_reached] : booking.umpire_reached,
      water_arranged: params.key?(:water_arranged) ? params[:water_arranged] : booking.water_arranged,
      balls_ready:    params.key?(:balls_ready)    ? params[:balls_ready]    : booking.balls_ready,
      ground_ready:   params.key?(:ground_ready)   ? params[:ground_ready]   : booking.ground_ready
    )
    render json: booking.as_json(include: [:ground, :slot, :user]), status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def admin_index
    bookings = Booking.includes(:ground, :slot, :user).order(created_at: :desc)
    render json: bookings.as_json(include: [:ground, :slot, :user]), status: :ok
  end

  def today
    today = Date.today.to_s
    bookings = Booking.includes(:ground, :slot, :user)
      .joins(:slot)
      .where(booking_date: today, status: "confirmed")
      .order("slots.start_time ASC")
    render json: bookings.as_json(include: [:ground, :slot, :user]), status: :ok
  end

  def upcoming
    start_date = Date.today
    end_date   = 3.days.from_now.to_date
    bookings = Booking.includes(:ground, :slot, :user)
      .where(booking_date: start_date..end_date, status: "confirmed")
      .order(booking_date: :asc)
    render json: bookings.as_json(include: [:ground, :slot, :user]), status: :ok
  end

  def reset_reminder
    booking = Booking.find(params[:id])
    booking.update(reminder_sent: false, reminder_sent_at: nil)
    render json: { message: "Reminder status reset" }, status: :ok
  end

  private

  def booking_params
    params.permit(:slot_id, :ground_id, :booking_date, :total_price, :match_type)
  end
end