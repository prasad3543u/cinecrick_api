class SlotsController < ApplicationController
  def index
    slots = if params[:ground_id]
      Slot.where(ground_id: params[:ground_id])
    else
      Slot.all
    end

    render json: slots, status: :ok
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
    params.permit(:ground_id, :slot_date, :start_time, :end_time, :price, :status)
  end
end