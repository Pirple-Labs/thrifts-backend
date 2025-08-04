module Payments
  class MerchantPaymentGenerator
    def self.call(payment)
      return unless payment.completed?

      payment.orders.includes(:shop).each do |order|
        MerchantPayment.create!(
          payment_id: payment.id,
          shop_id: order.shop_id,
          order_id: order.id,
          amount: order.total_price,
          status: "escrowed",
          escrowed_at: Time.current
        )
      end
    end
  end
end
