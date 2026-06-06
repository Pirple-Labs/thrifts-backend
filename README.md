# Thrifts Backend

A Rails 8 API powering the [Thrifts](https://github.com/jessemutua/thrifts) e-commerce marketplace. Handles authentication, product management, orders, M-Pesa payments, AI-powered image moderation, personalised feeds, and product recommendations — all built for the Nairobi thrift/second-hand market.

---

## Overview

The backend serves two client types simultaneously:

- **Buyers** — browse a personalised product feed, manage cart and wishlist, place orders, and pay via M-Pesa STK Push
- **Merchants** — create shops, manage product listings (with schema-based validation and image moderation), track orders, and receive analytics

It also integrates with the [Agents microservice](https://github.com/jessemutua/agents) for GPT-4o image moderation and FAISS-based product recommendations, and with a Python Personalization Operator for AI-generated feed layouts.

---

## Features

### Auth
- Email/password login and registration via Devise + bcrypt
- Google OAuth via `google-id-token` — find-or-create on first sign-in
- JWT-based session management via `devise-jwt` with a denylist revocation strategy

### Products
- **Schema-based products** — dynamic attribute validation driven by `Schema` records per category (draft → published workflow)
- **Legacy products** — simpler direct-publish flow for backwards compatibility
- Automatic image moderation on create via the Sentry agent (single and batch)
- pgvector embeddings re-queued on create/update for recommendation freshness
- Brand associations, subcategory, material, style, use_case, seasonality, and specification metadata

### Merchant Dashboard
- Full product CRUD (paginated, with shop scoping)
- Publish/unpublish with schema validation gate
- Order management with status transitions
- Store performance metrics and notifications

### Recommendations
- Similar products via vector search (pgvector)
- Complementary products via GPT-4 + FAISS (delegated to the Agents microservice)
- Results stored as `SimilarProduct` and `ComplementaryProduct` records, refreshable on demand

### Personalised Feed
- AI-driven home feed via a Python Operator service
- `Feed`, `FeedItem`, and `FeedExposure` models for tracking what users see
- Dynamic feed endpoint with cold-start handling, device-aware pagination, and injection support
- Page-specific layouts (`home_grid`, `pdp/layout`, `wishlist/layout`, `checkout/layout`, `profile/top-picks`) driven by Playbooks
- A/B experiment framework (`Experiment`, `ExperimentAssignment`, `ExposureOutcome`)

### Payments (M-Pesa)
- STK Push via Safaricom Daraja API — prompts buyer's phone with payment request
- Callback endpoint (no auth, verified by Daraja signature) — updates `Payment` record status
- Status lifecycle: `pending → success / failed / cancelled / timeout`
- Merchant withdrawal support
- Phone number normalisation (07xx, 01xx, +254, 254)

### Moderation
- Delegates to the Agents Flask service (`POST /moderate`, `POST /moderate/batch`)
- Results logged as `ModerationEvent` records
- Products auto-moderated on image upload; batch moderation endpoint available

### Admin & Monitoring
- Token-protected admin metrics: database, business, experiments, costs, performance, SLO status
- `DailyMetricsRollupJob` — aggregates `ApiUsage` into `PlanMetric` records nightly
- `ExposureOutcomesJob`, `PartitionRotationJob`, `PlaybookRefreshJob`, `ReembedProductJob`

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Rails 8.0 (API mode) |
| Database | PostgreSQL + pgvector |
| Auth | Devise + devise-jwt + Google ID Token |
| Background jobs | Solid Queue (in-process with Puma) |
| Cache | Solid Cache |
| HTTP clients | Faraday, HTTParty, Net::HTTP |
| Image uploads | Cloudinary |
| Payments | Safaricom Daraja (M-Pesa STK Push) |
| AI integration | Python Agents microservice (GPT-4o, FAISS) |
| Personalisation | Python Operator/Planner service |
| Pagination | Kaminari |
| Deployment | Render / Docker |

---

## Project Structure

```
thrifts-backend/
├── app/
│   ├── controllers/api/
│   │   ├── auth/            # manual_login, google_login, signup
│   │   ├── users/           # cart, wishlist, orders, delivery addresses, profile
│   │   ├── merchants/       # shop, products (CRUD + publish), orders, product_options
│   │   ├── products/        # buyer-facing product index + show
│   │   ├── payments/        # stk_push, daraja_callbacks, withdrawals
│   │   ├── recommendations/ # picks, show, refresh
│   │   ├── moderations/     # single + batch product moderation
│   │   ├── admin/           # metrics (database, business, experiments, costs)
│   │   ├── feed_controller.rb        # personalised feed (start, next, home_grid, dynamic)
│   │   ├── pdp_controller.rb         # product detail page layout
│   │   ├── checkout_controller.rb
│   │   ├── wishlist_controller.rb
│   │   ├── profile_controller.rb
│   │   └── schemas_controller.rb     # dynamic product form schemas
│   │
│   ├── models/
│   │   ├── user.rb          # Devise + JWT; has_one shop, has_many orders/cart/wishlist
│   │   ├── shop.rb          # belongs_to user, has_many products
│   │   ├── product.rb       # schema/legacy dual mode, pgvector, auto-moderation
│   │   ├── order.rb / order_item.rb
│   │   ├── payment.rb       # M-Pesa STK Push lifecycle
│   │   ├── cart_item.rb / wishlist_item.rb / delivery_address.rb
│   │   ├── feed.rb / feed_item.rb / feed_exposure.rb
│   │   ├── experiment.rb / experiment_assignment.rb / exposure_outcome.rb
│   │   ├── schema.rb        # dynamic product form definitions
│   │   ├── similar_product.rb / complementary_product.rb / recommended_product.rb
│   │   ├── product_embedding.rb
│   │   ├── moderation_event.rb
│   │   ├── plan_metric.rb / api_usage.rb / playbook.rb
│   │   ├── category.rb / brand.rb
│   │   └── jwt_denylist.rb
│   │
│   ├── services/
│   │   ├── moderation_service.rb           # Delegates to Agents Flask service
│   │   ├── recommendation_service.rb
│   │   ├── schema_validator.rb             # Validates schema_attributes against Schema
│   │   ├── payments/
│   │   │   ├── daraja_client.rb            # Faraday wrapper for Safaricom API
│   │   │   ├── b2c_payout_service.rb
│   │   │   └── merchant_payment_generator.rb
│   │   └── personalization/
│   │       ├── planner_client.rb           # HTTP client for Python Planner
│   │       ├── operator_http_client.rb     # HTTP client for Python Operator
│   │       ├── playbook_executor.rb / playbook_generator.rb / playbook_manager.rb
│   │       ├── vector_search.rb            # pgvector queries
│   │       ├── ranker.rb / intent_engine.rb
│   │       ├── snapshot_builder.rb / profile_store.rb / profile_hasher.rb
│   │       ├── response_shaper.rb / section_validator.rb / slate_writer.rb
│   │       └── ... (20+ personalization service files)
│   │
│   └── jobs/
│       ├── daily_metrics_rollup_job.rb     # Nightly ApiUsage → PlanMetric aggregation
│       ├── reembed_product_job.rb          # Re-queues pgvector embedding on product change
│       ├── playbook_refresh_job.rb
│       ├── exposure_outcomes_job.rb
│       └── partition_rotation_job.rb
│
├── config/routes.rb           # Full API routing (see API Reference below)
├── db/schema.rb               # Canonical database schema
├── render.yaml                # Render deployment config
├── docker-compose.yml         # Docker staging environment
├── Dockerfile / Dockerfile.dev / Dockerfile.render
└── vision_service/            # Python vision/embedding helper
```

---

## API Reference

All authenticated endpoints require `Authorization: Bearer <jwt>`.

### Auth (`/api/auth/`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/auth/manual_login` | Public | Email + password login |
| `POST` | `/api/auth/google_login` | Public | Google ID token login |
| `POST` | `/api/auth/signup` | Public | Register new account |

**Login/Signup response:**
```json
{ "user": { "id": 1, "email": "...", "name": "..." }, "token": "<jwt>" }
```

---

### Users (`/api/users/`)

| Method | Path | Description |
|---|---|---|
| `PATCH` | `/api/users/profile` | Update profile |
| `GET` | `/api/users/cart_items` | Fetch cart |
| `POST` | `/api/users/cart_items` | Add to cart |
| `POST` | `/api/users/cart_items/sync` | Sync local cart to backend |
| `DELETE` | `/api/users/cart_items` | Remove cart item |
| `DELETE` | `/api/users/cart_items/destroy_all` | Clear cart |
| `GET` | `/api/users/wishlist_items` | Fetch wishlist |
| `POST` | `/api/users/wishlist_items` | Add to wishlist |
| `POST` | `/api/users/wishlist_items/sync` | Sync wishlist |
| `DELETE` | `/api/users/wishlist_items` | Remove from wishlist |
| `GET` | `/api/users/delivery_addresses` | List addresses |
| `POST` | `/api/users/delivery_addresses` | Create address |
| `DELETE` | `/api/users/delivery_addresses/:id` | Delete address |
| `GET` | `/api/users/orders` | Buyer order history |
| `POST` | `/api/users/orders` | Place order |
| `GET` | `/api/users/orders/:id` | Order detail |
| `PUT` | `/api/users/orders/:id/mark_picked_up` | Mark as picked up |

---

### Merchants (`/api/merchants/`)

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/merchants/shop` | Create shop |
| `GET` | `/api/merchants/shop/my_shop` | Fetch own shop |
| `GET` | `/api/merchants/shop/:id/show_public` | Public shop profile |
| `GET` | `/api/merchants/shop/:id/products_public` | Public product listing |
| `GET` | `/api/merchants/products` | List own products (paginated) |
| `POST` | `/api/merchants/products` | Create product (legacy or schema-based) |
| `PATCH` | `/api/merchants/products/:id` | Update product |
| `DELETE` | `/api/merchants/products/:id` | Delete product |
| `POST` | `/api/merchants/products/:id/publish` | Publish draft product |
| `GET` | `/api/merchants/orders` | List orders |
| `PATCH` | `/api/merchants/orders/:id/update_status` | Update order status |

---

### Products — Buyer-facing (`/api/products/`)

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/products/products` | Paginated product feed |
| `GET` | `/api/products/products/:id` | Product detail |
| `GET` | `/api/products/:id` | Alias for product detail |
| `GET` | `/api/categories` | All categories |

---

### Recommendations (`/api/recommendations/`)

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/recommendations/picks` | Personalised picks for current user |
| `GET` | `/api/recommendations/:product_id` | Similar + complementary for a product |
| `POST` | `/api/recommendations/:product_id/refresh` | Trigger recommendation refresh |

---

### Payments (`/api/payments/`)

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/payments/stk_push` | Required | Initiate M-Pesa STK Push |
| `POST` | `/api/payments/callback` | None | Safaricom Daraja webhook |
| `GET` | `/api/payments/:id` | Required | Payment status |
| `GET` | `/api/payments/withdrawals` | Required | Merchant withdrawal history |
| `POST` | `/api/payments/withdrawals` | Required | Request withdrawal |

**STK Push request:**
```json
{ "amount": 500, "phone": "0712345678", "account_reference": "ORDER-42" }
```

**STK Push response:**
```json
{
  "id": 7,
  "status": "pending",
  "amount": 500,
  "msisdn": "254712345678",
  "CheckoutRequestID": "ws_CO_...",
  "MerchantRequestID": "..."
}
```

M-Pesa result codes handled: `0` (success), `1032` (cancelled), `2006`/`1037` (timeout), everything else (failed).

---

### Moderation (`/api/moderations/`)

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/moderations/products/:id` | Moderate a product image |
| `POST` | `/api/moderations/batch` | Batch moderate multiple products |

---

### Feeds & Layouts

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/api/feeds/start` | Optional | Start personalised feed session |
| `POST` | `/api/feeds/next` | Optional | Fetch next feed page |
| `GET` | `/api/feeds/dynamic/:page` | Optional | Dynamic AI-generated feed for a page |
| `GET` | `/api/home/grid` | Optional | Home grid with pagination + injections |
| `GET` | `/api/pdp/layout` | Optional | Product detail page layout |
| `GET` | `/api/wishlist/layout` | Optional | Wishlist page layout |
| `GET` | `/api/checkout/layout` | Optional | Checkout layout |
| `GET` | `/api/profile/top-picks` | Optional | Profile page top picks |

---

### Schemas (`/api/schemas/`)

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/schemas` | List all schemas |
| `GET` | `/api/schemas/:id` | Schema detail |
| `POST` | `/api/schemas` | Create schema |
| `PATCH` | `/api/schemas/:id` | Update schema |
| `GET` | `/api/schemas/categories` | Categories with schemas |

---

### Admin (`/api/admin/`)

All require admin token. Metrics endpoints: `GET /api/admin/metrics/database`, `/business`, `/experiments`, `/costs`, `/performance`, `/slo_status`.

---

## Getting Started (Local)

### Prerequisites
- Ruby 3.x
- PostgreSQL with pgvector extension
- The [Agents microservice](https://github.com/jessemutua/agents) running locally on port 5000

### Setup

```bash
git clone https://github.com/Pirple-Labs/thrifts-backend.git
cd thrifts-backend
bundle install
```

Create a `.env` file (or set environment variables):

```env
DATABASE_URL=postgresql://postgres:password@localhost:5432/thrifts_development
JWT_SECRET_KEY=your-jwt-secret
GOOGLE_CLIENT_ID=your-google-client-id

# M-Pesa (Safaricom Daraja)
MPESA_CONSUMER_KEY=...
MPESA_CONSUMER_SECRET=...
MPESA_SHORTCODE=...
MPESA_PASSKEY=...
MPESA_CALLBACK_URL=https://your-domain.com/api/payments/callback
MPESA_BASE_URL=https://sandbox.safaricom.co.ke

# Agents microservice
SENTRY_AGENT_URL=http://127.0.0.1:5000/moderate
SENTRY_AGENT_BATCH_URL=http://127.0.0.1:5000/moderate/batch

# Optional: skip moderation in development
SKIP_MODERATION=1
```

```bash
rails db:create db:migrate db:seed
rails server
```

API available at `http://localhost:3000`.

---

## Docker (Staging)

A full Docker environment is included with cross-platform scripts:

```bash
# Linux / macOS
./scripts/docker-staging.sh start

# Windows (PowerShell)
.\scripts\docker-staging.ps1 start
```

Available commands: `start`, `stop`, `restart`, `logs`, `shell`, `db`, `clean`, `build`, `test`, `migrate`, `seed`, `status`.

Services spun up: Rails app (port 3000), PostgreSQL (port 5432), Redis (port 6379).

---

## Deployment (Render)

`render.yaml` defines a Render web service + managed PostgreSQL:

```yaml
buildCommand: bundle install && bundle exec rails assets:precompile && bundle exec rails db:migrate
startCommand: bundle exec rails server -p $PORT
```

Set the following in the Render dashboard:

| Variable | Description |
|---|---|
| `DATABASE_URL` | Auto-set by Render from linked database |
| `RAILS_MASTER_KEY` | Auto-generated by Render |
| `JWT_SECRET_KEY` | Long random string |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID |
| `MPESA_*` | Daraja API credentials |
| `SENTRY_AGENT_URL` | URL of the deployed Agents service |
| `SKIP_MODERATION` | Set to `1` to disable in staging |

---

## Background Jobs

Solid Queue runs in-process with Puma (set `SOLID_QUEUE_IN_PUMA=true`).

| Job | Trigger | Purpose |
|---|---|---|
| `DailyMetricsRollupJob` | Nightly | Aggregates ApiUsage into PlanMetric |
| `ReembedProductJob` | After product create/update | Re-generates pgvector embedding |
| `PlaybookRefreshJob` | Scheduled | Refreshes AI playbooks |
| `ExposureOutcomesJob` | Scheduled | Processes feed exposure outcomes for A/B experiments |
| `PartitionRotationJob` | Scheduled | Rotates time-series table partitions |

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `JWT_SECRET_KEY` | Yes | Secret for JWT signing |
| `GOOGLE_CLIENT_ID` | Yes | Google OAuth audience (comma-separated for multiple) |
| `MPESA_CONSUMER_KEY` | For payments | Daraja API key |
| `MPESA_CONSUMER_SECRET` | For payments | Daraja API secret |
| `MPESA_SHORTCODE` | For payments | M-Pesa business shortcode |
| `MPESA_PASSKEY` | For payments | M-Pesa Lipa Na passkey |
| `MPESA_CALLBACK_URL` | For payments | Public callback URL |
| `MPESA_BASE_URL` | For payments | Daraja base URL (sandbox or production) |
| `SENTRY_AGENT_URL` | For moderation | Agents service single moderation endpoint |
| `SENTRY_AGENT_BATCH_URL` | For moderation | Agents service batch moderation endpoint |
| `SKIP_MODERATION` | No | Set `1` to skip image moderation in dev |

---

## Related Repos

| Repo | Description |
|---|---|
| [thrifts (frontend)](https://github.com/jessemutua/thrifts) | React + Vite buyer/merchant web app |
| [agents](https://github.com/jessemutua/agents) | Python Flask microservice — GPT-4o moderation + FAISS recommendations |

---

## License

Private — all rights reserved.
