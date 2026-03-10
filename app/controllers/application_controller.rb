
class ApplicationController < ActionController::API
  def current_user
    return @current_user if defined?(@current_user)

    header = request.headers["Authorization"]
    return @current_user = nil unless header.present?

    token = header.split(" ").last
    decoded = JsonWebToken.decode(token)
    return @current_user = nil unless decoded && decoded[:user_id]

    @current_user = User.find_by(id: decoded[:user_id])
  rescue
    @current_user = nil
  end

  def authenticate_request
    render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
  end
end