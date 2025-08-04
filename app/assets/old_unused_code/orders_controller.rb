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

    def create
      address = current_user.delivery_addresses.find_by(id: params[:address_id])
      unless address
        return render json: { success: false, error: "Invalid delivery address" }, status: :unprocessable_entity
      end

      orders = []

      params[:orders].each do |order_data|
        shop_id = order_data[:shop_id]
        products = order_data[:products]

        total = products.sum do |item|
          product = Product.find(item[:product_id])
          product.price.to_f * item[:quantity].to_i
        end

        order = current_user.orders.create!(
          shop_id: shop_id,
          delivery_address_id: address.id,
          total_price: total,
          status: "pending"
        )

        products.each do |item|
          product = Product.find(item[:product_id])
          order.order_items.create!(
            product_id: product.id,
            quantity: item[:quantity],
            price: product.price # Store actual product price at time of order
          )
        end

        orders << order
      end

      render json: {
        success: true,
        message: "Orders placed successfully",
        order_ids: orders.map(&:id)
      }
    rescue => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end

    # ✅ NEW: User marks order as picked up from the pickup station
    def mark_picked_up
      order = current_user.orders.find_by(id: params[:id])

      unless order
        return render json: { success: false, error: "Order not found" }, status: :not_found
      end

      unless order.status == "shipped"
        return render json: { success: false, error: "Only shipped orders can be marked as picked up" }, status: :unprocessable_entity
      end

      order.update!(status: "picked_up")

      render json: {
        success: true,
        message: "Order marked as picked up",
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
