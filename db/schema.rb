# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_04_070102) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_cart_items_on_product_id"
    t.index ["user_id"], name: "index_cart_items_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "complementary_products", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "complementary_product_id", null: false
    t.string "triggered_by"
    t.float "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_complementary_products_on_product_id"
  end

  create_table "conditions", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "delivery_addresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "nickname"
    t.string "phone"
    t.string "location"
    t.string "pickup_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_delivery_addresses_on_user_id"
  end

  create_table "delivery_modes", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "merchant_payments", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.bigint "shop_id", null: false
    t.bigint "order_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "status", default: "escrowed", null: false
    t.datetime "escrowed_at"
    t.datetime "released_at"
    t.datetime "transferred_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_merchant_payments_on_order_id"
    t.index ["payment_id"], name: "index_merchant_payments_on_payment_id"
    t.index ["shop_id"], name: "index_merchant_payments_on_shop_id"
  end

  create_table "merchant_wallets", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.decimal "balance", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_merchant_wallets_on_shop_id", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "pending"
    t.integer "total_items", default: 0
    t.decimal "total_price", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "shop_id", null: false
    t.bigint "delivery_address_id", null: false
    t.bigint "payment_id", null: false
    t.index ["delivery_address_id"], name: "index_orders_on_delivery_address_id"
    t.index ["payment_id"], name: "index_orders_on_payment_id"
    t.index ["shop_id"], name: "index_orders_on_shop_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payment_methods", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "total_amount", precision: 10, scale: 2, null: false
    t.string "status", default: "pending", null: false
    t.string "mpesa_checkout_request_id"
    t.string "mpesa_receipt_number"
    t.string "phone_number_used"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "sku"
    t.string "size"
    t.string "color"
    t.integer "stock", default: 0, null: false
    t.decimal "price_override", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "size", "color"], name: "index_product_variants_on_product_id_and_size_and_color", unique: true
    t.index ["product_id"], name: "index_product_variants_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.string "main_image"
    t.decimal "price"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "views"
    t.bigint "shop_id", null: false
    t.jsonb "supplementary_images"
    t.bigint "category_id"
    t.string "color"
    t.string "size"
    t.integer "stock"
    t.string "moderation_label"
    t.float "moderation_confidence"
    t.datetime "last_indexed_at"
    t.text "moderation_reason"
    t.string "moderation_status", default: "pending"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["shop_id"], name: "index_products_on_shop_id"
  end

  create_table "recommended_products", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.integer "rank", default: 0
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_recommended_products_on_product_id"
    t.index ["user_id", "product_id"], name: "index_recommended_products_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_recommended_products_on_user_id"
  end

  create_table "shops", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone"
    t.string "location"
    t.string "pickup_agent"
    t.boolean "agreed"
    t.string "store_logo_url"
    t.index ["user_id"], name: "index_shops_on_user_id"
  end

  create_table "similar_products", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "similar_product_id", null: false
    t.float "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_similar_products_on_product_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "google_id"
    t.string "avatar"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "role", default: 0, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "wishlist_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_wishlist_items_on_product_id"
    t.index ["user_id", "product_id"], name: "index_wishlist_items_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_wishlist_items_on_user_id"
  end

  create_table "withdrawal_requests", force: :cascade do |t|
    t.bigint "merchant_wallet_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "status", default: "requested", null: false
    t.string "mpesa_conversation_id"
    t.string "mpesa_receipt_number"
    t.string "phone_number"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_wallet_id"], name: "index_withdrawal_requests_on_merchant_wallet_id"
  end

  add_foreign_key "cart_items", "products"
  add_foreign_key "cart_items", "users"
  add_foreign_key "complementary_products", "products"
  add_foreign_key "complementary_products", "products", column: "complementary_product_id"
  add_foreign_key "delivery_addresses", "users"
  add_foreign_key "merchant_payments", "orders"
  add_foreign_key "merchant_payments", "payments"
  add_foreign_key "merchant_payments", "shops"
  add_foreign_key "merchant_wallets", "shops"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "delivery_addresses"
  add_foreign_key "orders", "payments"
  add_foreign_key "orders", "shops"
  add_foreign_key "orders", "users"
  add_foreign_key "payments", "users"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "categories"
  add_foreign_key "products", "shops"
  add_foreign_key "recommended_products", "products"
  add_foreign_key "recommended_products", "users"
  add_foreign_key "shops", "users"
  add_foreign_key "similar_products", "products"
  add_foreign_key "similar_products", "products", column: "similar_product_id"
  add_foreign_key "wishlist_items", "products"
  add_foreign_key "wishlist_items", "users"
  add_foreign_key "withdrawal_requests", "merchant_wallets"
end
