module Api
  module Merchant
    class OrdersController < Api::BaseController
      before_action :ensure_merchant_has_shop!

      # GET /api/merchant/orders
      def index
        shop = current_user.shop

        orders = Order
                   .joins(order_items: :product)
                   .where(products: { shop_id: shop.id })
                   .distinct
                   .includes(:user, order_items: :product)
                   .order(created_at: :desc)

        render json: {
          success: true,
          orders: orders.map { |order| serialize_order(order, shop.id) }
        }
      end

      # PATCH /api/merchant/orders/:id/update_status
      def update_status
        shop_id = current_user.shop.id

        order = Order
                  .joins(order_items: :product)
                  .where(products: { shop_id: shop_id })
                  .distinct
                  .find_by(id: params[:id])

        unless order
          return render json: {
            success: false,
            error: "Order not found or not related to your shop"
          }, status: :not_found
        end

        requested_status = params[:status].to_s.strip.downcase
        allowed_statuses = %w[processing shipped]

        unless allowed_statuses.include?(requested_status)
          return render json: {
            success: false,
            error: "Invalid status transition. Allowed: #{allowed_statuses.join(', ')}"
          }, status: :unprocessable_entity
        end

        if order.update(status: requested_status)
          render json: {
            success: true,
            message: "Order status updated to '#{requested_status}'"
          }, status: :ok
        else
          render json: {
            success: false,
            error: order.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def ensure_merchant_has_shop!
        unless current_user&.shop
          render json: {
            success: false,
            error: "Shop not found for current user"
          }, status: :not_found
        end
      end

      def serialize_order(order, shop_id)
        {
          id: order.id,
          status: order.status,
          total_price: order.total_price,
          placed_on: order.created_at.strftime("%b %d, %Y"),
          user: {
            id: order.user.id,
            name: order.user.name
          },
          items: order.order_items.select { |item| item.product.shop_id == shop_id }.map do |item|
            {
              product_id: item.product.id,
              name: item.product.name,
              quantity: item.quantity,
              unit_price: item.price,
              subtotal: item.quantity * item.price
            }
          end
        }
      end
    end
  end
end
