module Api
  module Users
    class OrdersController < Api::BaseController
      def index
        orders = current_user.orders
                             .includes(order_items: :product)
                             .order(created_at: :desc)

        ongoing_orders = orders.select { |o| o.status != "delivered" }
        past_orders    = orders.select { |o| o.status == "delivered" }

        render json: {
          success: true,
          ongoing_orders: ongoing_orders.map { |order| serialize_order(order) },
          past_orders: past_orders.map { |order| serialize_order(order) }
        }
      end

    def create
      address = current_user.delivery_addresses.find_by(id: params[:address_id])
      return render json: { success: false, error: "Invalid delivery address" }, status: :unprocessable_entity unless address

      # 1) Payment must exist and be success
      payment = Payment.find_by(id: params[:payment_id], user_id: current_user.id)
      return render json: { success: false, error: "Payment not found" }, status: :unprocessable_entity unless payment
      return render json: { success: false, error: "Payment not completed" }, status: :unprocessable_entity unless payment.status == "success"

      # 2) Orders payload must be an array
      orders_param = params[:orders]
      return render json: { success: false, error: "Invalid orders payload" }, status: :unprocessable_entity unless orders_param.is_a?(Array) && orders_param.any?

      # 3) Compute grand total (robustly) and verify it’s covered by payment.amount (whole KES)
      grand_total = orders_param.inject(0.0) do |acc, order_data|
        products = Array(order_data[:products])
        sub = products.inject(0.0) do |acc2, item|
          pid = item[:product_id] || item["product_id"]
          qty = (item[:quantity] || item["quantity"]).to_i
          product = Product.find(pid) # raises if nil/invalid → rescued below
          acc2 + product.price.to_f * qty
        end
        acc + sub
      end
      grand_total_int = grand_total.round
      if payment.amount.to_i < grand_total_int
        return render json: { success: false, error: "Payment amount (#{payment.amount}) is less than order total (#{grand_total_int})" },
                      status: :unprocessable_entity
      end

      created = []
      ActiveRecord::Base.transaction do
        orders_param.each do |order_data|
          shop_id  = order_data[:shop_id] || order_data["shop_id"]
          products = Array(order_data[:products])

          total  = products.inject(0.0) do |acc, item|
            pid = item[:product_id] || item["product_id"]
            qty = (item[:quantity] || item["quantity"]).to_i
            product = Product.find(pid)
            acc + product.price.to_f * qty
          end
          items_count = products.sum { |i| (i[:quantity] || i["quantity"]).to_i }

          order = current_user.orders.create!(
            shop_id:             shop_id,
            delivery_address_id: address.id,
            total_price:         total,
            total_items:         items_count,
            status:              "paid",          # payment already succeeded
            payment_id:          payment.id
          )

          products.each do |item|
            pid = item[:product_id] || item["product_id"]
            qty = (item[:quantity] || item["quantity"]).to_i
            product = Product.find(pid)
            order.order_items.create!(product_id: product.id, quantity: qty, price: product.price)
          end

          created << order
        end
      end

      render json: { success: true, message: "Orders created", order_ids: created.map(&:id) }
    rescue => e
      Rails.logger.error("[Orders][CREATE][ERROR] #{e.class}: #{e.message}")
      render json: { success: false, error: e.message }, status: :internal_server_error
    end


      def mark_picked_up
        order = current_user.orders.find_by(id: params[:id])
        return render json: { success: false, error: "Order not found" }, status: :not_found unless order
        return render json: { success: false, error: "Only shipped orders can be marked as picked up" }, status: :unprocessable_entity unless order.status == "shipped"

        ActiveRecord::Base.transaction do
          order.update!(status: "picked_up")

          merchant_payment = MerchantPayment.find_by(order_id: order.id, status: "escrowed")
          if merchant_payment.present?
            merchant_payment.update!(status: "released", released_at: Time.current)
            wallet = MerchantWallet.find_or_create_by!(shop_id: order.shop_id)
            wallet.update!(balance: wallet.balance + merchant_payment.amount)
          end
        end

        render json: {
          success: true,
          message: "Order marked as picked up and funds released to merchant",
          order_id: order.id
        }
      end

      private

      def serialize_order(order)
        {
          id: order.id,
          status: order.status,
          total_items: order.total_items,
          total_price: order.total_price,
          placed_on: order.created_at.strftime("%b %d, %Y"),
          items: order.order_items.map do |item|
            product = item.product
            {
              product_id: product.id,
              name: product.name,
              main_image: product.main_image,
              quantity: item.quantity,
              unit_price: item.price,
              subtotal: item.price * item.quantity
            }
          end
        }
      end
    end
  end
end
