# frozen_string_literal: true

require 'json'

# Ensure a demo user exists
user = User.find_or_create_by!(email: 'demo_user@example.com') do |u|
  u.password = 'Password123!'
end

# Provided AI playbook JSON (canonical schema)
json_str = <<~JSON
{
  "ai_generated": true,
  "ai_metadata": {
    "cost_usd": 0.0,
    "duration_ms": 1,
    "model_version": "gpt-4o-mini",
    "prompt_version": "playbook_v3.0",
    "section_count": 4,
    "timestamp": "2025-01-15T10:25:00Z"
  },
  "content": {
    "caps": {
      "max_complementary_items": 8,
      "max_items": 36,
      "max_similar_items": 12,
      "max_trending_items": 12
    },
    "modules": {
      "complete_sneakers": {
        "algorithm": "complementary",
        "filters": {
          "category": "sneakers",
          "reference_product": "White Nike Air Max",
          "search_terms": [
            "athletic wear",
            "sneakers accessories",
            "sports clothing"
          ],
          "style": "athletic"
        },
        "metadata": {
          "conversion_potential": "high",
          "title": "Complete Your Sneakers",
          "type": "complementary"
        }
      },
      "discovery_grid": {
        "algorithm": "diversity",
        "filters": {
          "brand": "Adidas",
          "brand_any_of": [
            "Adidas",
            "Puma",
            "New Balance"
          ],
          "category": "sneakers",
          "category_any_of": [
            "sneakers"
          ],
          "color_any_of": [
            "white"
          ],
          "diversity_boost": true,
          "excluded_products": [
            "White Nike Air Max"
          ],
          "fresh_days": 30,
          "per_brand_cap": 3,
          "per_shop_cap": 2,
          "price_buckets": [
            [
              75,
              120
            ],
            [
              121,
              180
            ],
            [
              181,
              240
            ]
          ],
          "search_terms": [
            "Nike sneakers alternatives",
            "white sneakers new arrivals",
            "athletic style picks"
          ],
          "style_any_of": [
            "athletic"
          ]
        },
        "metadata": {
          "conversion_potential": "high",
          "title": "Discover New Styles",
          "type": "discovery"
        }
      },
      "more_white_sneakers": {
        "algorithm": "similarity",
        "filters": {
          "color": "white",
          "price_range": [
            99,
            199
          ],
          "reference_product": "White Nike Air Max",
          "search_terms": [
            "White Nike Air Max",
            "similar white sneakers"
          ],
          "style": "athletic"
        },
        "metadata": {
          "conversion_potential": "medium",
          "title": "More White Sneakers Like This",
          "type": "similar"
        }
      },
      "trending_nike_sneakers": {
        "algorithm": "trending",
        "filters": {
          "brand": "Nike",
          "category": "sneakers",
          "color": "white",
          "fresh_days": 7,
          "search_terms": [
            "Nike sneakers athletic",
            "white sneakers"
          ],
          "style": "athletic"
        },
        "metadata": {
          "conversion_potential": "high",
          "title": "Trending Nike Sneakers You'll Love",
          "type": "trending"
        }
      }
    },
    "priority": [
      "trending_nike_sneakers",
      "more_white_sneakers",
      "complete_sneakers",
      "discovery_grid"
    ],
    "thresholds": {
      "min_items": 3
    }
  },
  "generated_at": "2025-09-12T10:05:18Z",
  "page": "home",
  "playbook_id": "pb_demo_home_PLACEHOLDER",
  "user_context": {
    "intent": "browsing_sneakers",
    "region": "ke",
    "traits": [
      "price_explorer"
    ]
  },
  "user_insights": {
    "behavioral_patterns": [
      "price_explorer"
    ],
    "conversion_triggers": [
      "trending_items",
      "similar_products",
      "completion"
    ],
    "intent": "browsing_sneakers",
    "primary_interests": [
      "Nike",
      "sneakers",
      "white color",
      "athletic style"
    ]
  },
  "valid_for_hours": 48
}
JSON

data = JSON.parse(json_str)
data['playbook_id'] = "pb_demo_home_#{Time.now.to_i}"

pb = Playbook.create!(
  playbook_id: data['playbook_id'],
  user_id: user.id,
  page: data['page'],
  valid_for_hours: data['valid_for_hours'],
  generated_at: Time.current,
  ai_generated: true,
  content: data['content'],
  user_context: data['user_context'],
  ai_instructions: data['ai_metadata']
)

result = Personalization::PlaybookExecutor.execute_for_user(
  user.id,
  'home',
  { region: 'ke', session_id: "sess_#{SecureRandom.hex(4)}", pickup_only: false }
)

puts({ user_id: user.id, playbook_id: pb.playbook_id, page: pb.page }.to_json)
puts JSON.pretty_generate(result)





