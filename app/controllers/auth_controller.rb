class AuthController < ApplicationController
  def health
  render json: { status: "ok", app: "cinecrick_api" }, status: :ok
end
  # POST /auth/signup
  def signup
    user = User.new(user_params)

    if user.save
      token = JsonWebToken.encode(user_id: user.id)
      render json: { user: safe_user(user), token: token }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /auth/login
  def login
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      token = JsonWebToken.encode(user_id: user.id)
      render json: { user: safe_user(user), token: token }, status: :ok
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  # GET /me
  def me
    user = current_user
    if user
      render json: { user: safe_user(user) }, status: :ok
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  private

  # ✅ supports both payload styles:
  # { name, email, password, password_confirmation }
  # OR { auth: { ... } }
  def user_params
    params_to_use = params[:auth].presence || params
    params_to_use.permit(:name, :email, :password, :password_confirmation, :dob, :interest)
  end

  # ✅ this was missing in your controller (caused 500 error)
  def safe_user(user)
    { id: user.id, name: user.name, email: user.email, dob: user.dob, interest: user.interest}
  end

  # Reads Authorization: Bearer <token>
  def current_user
    header = request.headers["Authorization"]
    return nil unless header

    token = header.split(" ").last
    decoded = JsonWebToken.decode(token)
    return nil unless decoded && decoded[:user_id]

    User.find_by(id: decoded[:user_id])
  end
end