module Api
  module Payments
    class PaymentsController < Api::BaseController
      def show
        p = current_user.payments.find(params[:id])
        render json: {
          id: p.id,
          status: p.status,                 # "pending" | "success" | "failed" | "cancelled" | "timeout"
          result_code: p.result_code,
          result_desc: p.result_desc,
          mpesa_receipt_number: p.mpesa_receipt_number,
          completed_at: p.completed_at
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Not found" }, status: :not_found
      end
    end
  end
end
