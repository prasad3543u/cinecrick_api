class GroundsController < ApplicationController
  def index
    grounds = Ground.all
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

  private

  def ground_params
    params.permit(
      :name,
      :location,
      :sport_type,
      :price_per_hour,
      :opening_time,
      :closing_time,
      :image_url,
      :amenities
    )
  end
end