class GroundsController < ApplicationController
  before_action :authenticate_request, only: [:create, :update, :destroy, :generate_slots]

  def index
    grounds = Ground.order(created_at: :desc)
    render json: grounds, status: :ok
  end

  def show
    ground = Ground.find(params[:id])
    render json: ground, status: :ok
  end

  def create
    ground = Ground.new(ground_params)

    if ground.save
      render json: ground, status: :created
    else
      render json: { errors: ground.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    ground = Ground.find(params[:id])

    if ground.update(ground_params)
      render json: ground, status: :ok
    else
      render json: { errors: ground.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    ground = Ground.find(params[:id])
    ground.destroy
    render json: { message: "Ground deleted successfully" }, status: :ok
  end

  def generate_slots
    ground = Ground.find(params[:id])
    slot_date = params[:slot_date]

    if slot_date.blank?
      return render json: { error: "slot_date is required" }, status: :unprocessable_entity
    end

    date_obj = Date.parse(slot_date)

    holidays = [
      "2026-01-01",
      "2026-01-26",
      "2026-08-15"
    ]

    is_weekend = date_obj.saturday? || date_obj.sunday?
    is_holiday = holidays.include?(slot_date)

    slot_definitions =
      if is_weekend || is_holiday
        [
          { start_time: "06:30", end_time: "09:30", price: 4000 },
          { start_time: "09:30", end_time: "12:30", price: 3500 },
          { start_time: "13:00", end_time: "18:00", price: 3000 }
        ]
      else
        [
          { start_time: "06:30", end_time: "09:30", price: 2500 },
          { start_time: "09:30", end_time: "12:30", price: 2500 },
          { start_time: "13:00", end_time: "18:00", price: 2500 }
        ]
      end

    generated_slots = []

    slot_definitions.each do |slot_data|
      slot = Slot.find_or_initialize_by(
        ground_id: ground.id,
        slot_date: slot_date,
        start_time: slot_data[:start_time],
        end_time: slot_data[:end_time]
      )

      slot.price = slot_data[:price]
      slot.status = "available" if slot.status.blank?
      slot.max_teams = 2
      slot.teams_booked_count = 0 if slot.teams_booked_count.blank?
      slot.save!

      generated_slots << slot
    end

    render json: {
      message: "Slots generated successfully",
      ground: ground,
      slots: generated_slots
    }, status: :ok
  end

  private

  def ground_params
    params.permit(
      :name, :location, :sport_type, :price_per_hour,
      :opening_time, :closing_time, :image_url,
      :amenities, :admin_name, :admin_phone
    )
  end
end