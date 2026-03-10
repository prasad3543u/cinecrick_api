class AuthController < ApplicationController
  def health
    render json: { status: "ok", app: "cinecrick_api" }, status: :ok
  end

  def signup
    user = User.new(user_params)

    if user.save
      token = JsonWebToken.encode(user_id: user.id)
      render json: { user: safe_user(user), token: token }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      token = JsonWebToken.encode(user_id: user.id)
      render json: { user: safe_user(user), token: token }, status: :ok
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  def me
    user = current_user
    if user
      render json: { user: safe_user(user) }, status: :ok
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
   
  def make_admin
  email = params[:email]
  user = User.find_by(email: email)
  if user
    user.update(role: "admin")
    render json: { message: "Done", email: user.email, role: user.role }
  else
    # Show all users so you can see what emails exist
    render json: { error: "User not found", all_users: User.pluck(:email) }
  end
end

  private

  def user_params
    params_to_use = params[:auth].presence || params
    params_to_use.permit(:name, :email, :password, :password_confirmation, :dob, :interest)
  end

  def safe_user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      dob: user.dob,
      interest: user.interest,
      role: user.role
    }
  end
end