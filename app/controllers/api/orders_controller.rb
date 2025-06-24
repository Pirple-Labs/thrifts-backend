module Api
  class OrdersController < Api::BaseController
    # before_action :authenticate_user!

    def index
      orders = current_user.orders
        .includes(order_items: :product)
        .order(created_at: :desc)

      ongoing_orders = orders.select { |o| o.status != "delivered" }
      past_orders = orders.select { |o| o.status == "delivered" }

      render json: {
        success: true,
        ongoing_orders: ongoing_orders.map { |order| serialize_order(order) },
        past_orders: past_orders.map { |order| serialize_order(order) }
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
