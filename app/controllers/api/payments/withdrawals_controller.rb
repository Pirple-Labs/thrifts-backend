module Api
  module Payments
    class WithdrawalsController < BaseController
      def create
        shop = current_user.shop
        return render json: { success: false, error: "Merchant shop not found" }, status: :not_found unless shop

        amount = params[:amount].to_f
        phone  = params[:phone] || shop.phone

        return render json: { success: false, error: "Invalid withdrawal amount" }, status: :unprocessable_entity if amount <= 0

        wallet = MerchantWallet.find_or_create_by!(shop_id: shop.id)

        if wallet.balance < amount
          return render json: { success: false, error: "Insufficient wallet balance" }, status: :unprocessable_entity
        end

        response = ::Mpesa::B2cPayoutService.new(
          phone_number: phone,
          amount: amount,
          remarks: "Withdrawal for #{shop.name}"
        ).call

        if response["ResponseCode"] == "0"
          wallet.update!(balance: wallet.balance - amount)

          WithdrawalRequest.create!(
            merchant_wallet_id: wallet.id,
            amount: amount,
            status: "completed",
            mpesa_conversation_id: response["ConversationID"],
            mpesa_receipt_number: response["OriginatorConversationID"],
            phone_number: phone,
            completed_at: Time.current
          )

          render json: { success: true, message: "Withdrawal successful" }, status: :ok
        else
          render json: { success: false, error: response["errorMessage"] || "Withdrawal failed" }, status: :unprocessable_entity
        end
      end

      def index
        shop = current_user.shop
        return render json: { success: false, error: "Merchant shop not found" }, status: :not_found unless shop

        wallet = MerchantWallet.find_by(shop_id: shop.id)
        return render json: { success: true, withdrawals: [] } unless wallet

        withdrawals = WithdrawalRequest
          .where(merchant_wallet_id: wallet.id)
          .order(created_at: :desc)

        render json: {
          success: true,
          withdrawals: withdrawals.map do |w|
            {
              id: w.id,
              amount: w.amount,
              status: w.status,
              phone_number: w.phone_number,
              receipt: w.mpesa_receipt_number,
              requested_at: w.created_at.strftime("%b %d, %Y %H:%M"),
              completed_at: w.completed_at&.strftime("%b %d, %Y %H:%M")
            }
          end
        }
      end
    end
  end
end
