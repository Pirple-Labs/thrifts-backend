# app/controllers/api/users/profiles_controller.rb

module Api
  module Users
    class ProfilesController < Api::BaseController
      def update
        if current_user.update(profile_params)
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

      def profile_params
        params.permit(:avatar, :name)
      end
    end
  end
end
