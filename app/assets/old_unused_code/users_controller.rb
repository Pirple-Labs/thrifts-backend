module Api
  class UsersController < Api::BaseController
    # before_action :authenticate_user!

    # PATCH /api/user
    def update
      if current_user.update(user_params)
        render json: {
          success: true,
          user: current_user.slice(:id, :email, :name, :avatar)
        }
      else
        render json: {
          success: false,
          error: current_user.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    private

    def user_params
      params.permit(:avatar, :name) # Add :name or others as needed
    end
  end
end
