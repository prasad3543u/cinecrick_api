class SlotsController < ApplicationController
  before_action :authenticate_request, only: [:create, :update, :destroy]

  def index
    slots = Slot.all
    slots = slots.where(ground_id: params[:ground_id]) if params[:ground_id].present?
    slots = slots.where(slot_date: params[:slot_date]) if params[:slot_date].present?
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