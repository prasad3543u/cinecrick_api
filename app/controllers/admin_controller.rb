class AdminController < ApplicationController
  before_action :authenticate_request

  def stats
    total_grounds = Ground.count
    total_bookings = Booking.count
    total_users = User.count
    pending_bookings = Booking.where(status: "pending").count
    confirmed_bookings = Booking.where(status: "confirmed").count
    cancelled_bookings = Booking.where(status: "cancelled").count
    total_revenue = Booking.where(status: "confirmed").sum(:total_price)

    recent_bookings = Booking.includes(:ground, :slot, :user)
      .order(created_at: :desc)
      .limit(5)
      .as_json(include: [:ground, :slot, :user])

    popular_grounds = Ground.joins(:bookings)
      .group("grounds.id", "grounds.name")
      .order("count_all desc")
      .limit(5)
      .count
      .map { |k, v| { id: k[0], name: k[1], bookings: v } }

    render json: {
      total_grounds: total_grounds,
      total_bookings: total_bookings,
      total_users: total_users,
      pending_bookings: pending_bookings,
      confirmed_bookings: confirmed_bookings,
      cancelled_bookings: cancelled_bookings,
      total_revenue: total_revenue,
      recent_bookings: recent_bookings,
      popular_grounds: popular_grounds
    }, status: :ok
  end

  def block_date
    ground_id = params[:ground_id]
    date = params[:date]
    reason = params[:reason] || "Unavailable"

    if ground_id.blank? || date.blank?
      return render json: { error: "ground_id and date are required" }, status: :unprocessable_entity
    end

    # Mark all slots for this ground+date as blocked
    slots = Slot.where(ground_id: ground_id, slot_date: date)

    if slots.empty?
      return render json: { error: "No slots found for this date" }, status: :unprocessable_entity
    end

    slots.update_all(status: "blocked")

    render json: { message: "Date blocked successfully", date: date, slots_blocked: slots.count }, status: :ok
  end

  def unblock_date
    ground_id = params[:ground_id]
    date = params[:date]

    if ground_id.blank? || date.blank?
      return render json: { error: "ground_id and date are required" }, status: :unprocessable_entity
    end

    slots = Slot.where(ground_id: ground_id, slot_date: date, status: "blocked")
    slots.update_all(status: "available")

    render json: { message: "Date unblocked successfully", date: date, slots_unblocked: slots.count }, status: :ok
  end

  def blocked_dates
    ground_id = params[:ground_id]

    slots = if ground_id.present?
      Slot.where(ground_id: ground_id, status: "blocked")
    else
      Slot.where(status: "blocked")
    end

    blocked = slots.group_by(&:slot_date).map do |date, date_slots|
      { date: date, ground_id: date_slots.first.ground_id, slots_count: date_slots.count }
    end

    render json: blocked, status: :ok
  end
end