class PartnersController < ApplicationController
  before_action :authenticate_request
  before_action :set_grounds

  def dashboard
    bookings = Booking.includes(:ground, :slot, :user)
                      .where(ground_id: @grounds.pluck(:id))
                      .order(created_at: :desc)

    stats = {
      total_bookings: bookings.count,
      confirmed_bookings: bookings.where(status: "confirmed").count,
      pending_bookings: bookings.where(status: "pending").count,
      cancelled_bookings: bookings.where(status: "cancelled").count,
      total_revenue: bookings.where(status: "confirmed").sum(:total_price),
      pending_payments: PaymentBooking.where(booking_id: bookings.pluck(:id), status: "pending").sum(:amount),
      grounds_count: @grounds.count
    }

    render json: { stats: stats, bookings: bookings, grounds: @grounds }, status: :ok
  end

  def update_payment
    booking = Booking.find(params[:booking_id])
    unless @grounds.include?(booking.ground)
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    payment = PaymentBooking.find_or_initialize_by(booking_id: booking.id)
    payment.update(
      amount: params[:amount],
      status: params[:status],
      payment_date: params[:status] == "paid" ? Date.today : nil,
      notes: params[:notes]
    )
    render json: payment, status: :ok
  end

   def slots
  ground = Ground.find(params[:ground_id])
  date = params[:date]

  unless @grounds.include?(ground)
    return render json: { error: "Unauthorized" }, status: :unauthorized
  end

  slots = Slot.where(ground_id: ground.id, slot_date: date).order(:start_time)

  render json: slots.as_json(include: {
    bookings: {
      include: {
        user: { only: [:id, :name, :phone, :email] },
        payment_bookings: { only: [:amount, :status, :payment_date, :notes] },
        staff_payments: { only: [:staff_type, :name, :amount, :status, :paid_date, :paid_by] }
      }
    }
  }), status: :ok
end

  def update_staff_payment
    booking = Booking.find(params[:booking_id])
    unless @grounds.include?(booking.ground)
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    payment = StaffPayment.find_or_initialize_by(
      booking_id: booking.id,
      staff_type: params[:staff_type],
      name: params[:name]
    )
    payment.update(
      amount: params[:amount],
      status: params[:status],
      paid_date: params[:status] == "paid" ? Date.today : nil,
      paid_by: params[:paid_by]
    )
    render json: payment, status: :ok
  end

  private

  def set_grounds
    if current_user.role == "admin"
      @grounds = Ground.all
    else
      partner = Partner.find_by(user_id: current_user.id)
      if partner.nil?
        render json: { error: "Partner profile not found" }, status: :not_found
        return
      end
      @grounds = partner.grounds
    end
  end
end