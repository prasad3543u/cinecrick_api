class SlotsController < ApplicationController
  before_action :authenticate_request, only: [:create, :update, :destroy]

   def index
  slots = Slot.all
  slots = slots.where(ground_id: params[:ground_id]) if params[:ground_id].present?
  slots = slots.where(slot_date: params[:slot_date]) if params[:slot_date].present?

  # Auto-generate slots if none exist for this ground + date
  if params[:ground_id].present? && params[:slot_date].present?
    if slots.empty?
      ground = Ground.find_by(id: params[:ground_id])
      if ground
        date = Date.parse(params[:slot_date])
        holidays = ["2026-01-01", "2026-01-26", "2026-08-15"]
        is_weekend = date.saturday? || date.sunday?
        is_holiday = holidays.include?(params[:slot_date])

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

        slot_definitions.each do |s|
          Slot.create!(
            ground_id: ground.id,
            slot_date: params[:slot_date],
            start_time: s[:start_time],
            end_time: s[:end_time],
            price: s[:price],
            status: "available",
            max_teams: 2,
            teams_booked_count: 0
          )
        end

        # Reload slots after creation
        slots = Slot.where(ground_id: params[:ground_id], slot_date: params[:slot_date])
      end
    end
  end

  render json: slots.order(:slot_date, :start_time), status: :ok
end

  def show
    slot = Slot.find(params[:id])
    render json: slot, status: :ok
  end

  def create
    slot = Slot.new(slot_params)
    if slot.save
      render json: slot, status: :created
    else
      render json: { errors: slot.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    slot = Slot.find(params[:id])
    if slot.update(slot_params)
      render json: slot, status: :ok
    else
      render json: { errors: slot.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    slot = Slot.find(params[:id])
    slot.destroy
    render json: { message: "Slot deleted successfully" }, status: :ok
  end

  
  private

  def slot_params
    params.permit(
      :ground_id, :slot_date, :start_time, :end_time,
      :price, :status, :max_teams, :teams_booked_count
    )
  end
end