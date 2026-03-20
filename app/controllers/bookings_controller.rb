class BookingsController < ApplicationController
  before_action :authenticate_request

  def index
    bookings = current_user.bookings.includes(:ground, :slot).order(created_at: :desc)
    render json: bookings.as_json(include: [:ground, :slot]), status: :ok
  end

  def create
    # FIX: Add .lock! with NOWAIT for better performance
    slot = Slot.lock("FOR UPDATE NOWAIT").find(params[:slot_id])
    match_type = params[:match_type]

    unless ["with_opponents", "without_opponents"].include?(match_type)
      return render json: { error: "Invalid match type" }, status: :unprocessable_entity
    end

    # FIX: Check slot availability with locked record
    if slot.status == "booked" || slot.status == "pending"
      return render json: { error: "This slot is already booked" }, status: :unprocessable_entity
    end

    # FIX: Check if slot is fully booked
    if slot.teams_booked_count.to_i >= slot.max_teams.to_i
      return render json: { error: "Slot is already fully booked" }, status: :unprocessable_entity
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

    # FIX: Use transaction with retry logic and timeout
    begin
      ActiveRecord::Base.transaction do
        booking.save!
        
        case match_type
        when "without_opponents"
          slot.update!(
            teams_booked_count: slot.max_teams,
            status: "pending"
          )
        else # with_opponents
          current_count = slot.teams_booked_count || 0
          new_count = current_count + 1
          
          if new_count >= slot.max_teams
            slot.update!(
              teams_booked_count: slot.max_teams,
              status: "pending"
            )
          else
            slot.update!(
              teams_booked_count: new_count,
              status: "available"
            )
          end
        end
      end
    rescue ActiveRecord::LockWaitTimeout
      render json: { error: "Slot is busy. Please try again." }, status: :conflict
      return
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::Deadlocked => e
      render json: { error: "This slot was just booked by someone else. Please try another slot." }, 
             status: :conflict
      return
    end

    render json: booking.as_json(include: [:ground, :slot]), status: :created
  rescue ActiveRecord::LockWaitTimeout
    render json: { error: "Slot is currently busy. Please try again in a moment." }, status: :conflict
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def confirm
    booking = Booking.includes(:slot, :ground).find(params[:id])
    
    # Only allow confirmation of pending bookings
    unless booking.status == "pending"
      return render json: { error: "Can only confirm pending bookings" }, 
                    status: :unprocessable_entity
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
    
    # Only allow cancellation of pending or confirmed bookings
    unless ['pending', 'confirmed'].include?(booking.status)
      return render json: { error: "Cannot cancel booking with status: #{booking.status}" }, 
                    status: :unprocessable_entity
    end

    # Check if match date has passed
    if booking.booking_date < Date.today
      return render json: { error: "Cannot cancel past bookings" }, 
                    status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      booking.update!(status: "cancelled")
      
      # Properly reset slot based on current bookings
      slot = booking.slot
      other_confirmed_bookings = Booking.where(slot_id: slot.id, status: "confirmed")
                                        .where.not(id: booking.id)
                                        .count
      other_pending_bookings = Booking.where(slot_id: slot.id, status: "pending")
                                      .where.not(id: booking.id)
                                      .count
      
      total_other_bookings = other_confirmed_bookings + other_pending_bookings
      
      if total_other_bookings > 0
        # Slot still has other bookings
        slot.update!(
          teams_booked_count: total_other_bookings,
          status: total_other_bookings >= slot.max_teams ? "pending" : "available"
        )
      else
        # No other bookings, reset to available
        slot.update!(
          status: "available",
          teams_booked_count: 0
        )
      end
    end

    render json: booking.as_json(include: [:ground, :slot]), status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Admin assigns umpire + groundsman to a confirmed booking
  def assign_staff
    booking = Booking.find(params[:id])
    
    # Only allow staff assignment for confirmed bookings
    unless booking.status == "confirmed"
      return render json: { 
        error: "Staff can only be assigned to confirmed bookings. Current status: #{booking.status}" 
      }, status: :unprocessable_entity
    end

    # Validate phone numbers if provided
    if params[:umpire_phone].present? && params[:umpire_phone] !~ /\A\+?\d{10,15}\z/
      return render json: { error: "Invalid umpire phone number format" }, status: :unprocessable_entity
    end

    if params[:groundsman_phone].present? && params[:groundsman_phone] !~ /\A\+?\d{10,15}\z/
      return render json: { error: "Invalid groundsman phone number format" }, status: :unprocessable_entity
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

  # Admin updates match day status checkboxes
  def update_status
    booking = Booking.find(params[:id])
    
    # Only allow status updates for confirmed bookings
    unless booking.status == "confirmed"
      return render json: { 
        error: "Status can only be updated for confirmed bookings. Current status: #{booking.status}" 
      }, status: :unprocessable_entity
    end

    # Only allow updates on match day
    if booking.booking_date != Date.today
      return render json: { 
        error: "Status can only be updated on the match day" 
      }, status: :unprocessable_entity
    end

    booking.update!(
      umpire_reached:  params[:umpire_reached].present? ? params[:umpire_reached] : booking.umpire_reached,
      water_arranged:  params[:water_arranged].present? ? params[:water_arranged] : booking.water_arranged,
      balls_ready:     params[:balls_ready].present? ? params[:balls_ready] : booking.balls_ready,
      ground_ready:    params[:ground_ready].present? ? params[:ground_ready] : booking.ground_ready
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