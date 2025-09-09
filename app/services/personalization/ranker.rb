# app/services/personalization/ranker.rb
# frozen_string_literal: true
module Personalization
  class Ranker
    def self.call(pool:, region:)
      merchant_cap = 3
      by_merchant = Hash.new(0)

      scored = pool.map do |c|
        relevance = normalize(c[:vec_score]) * (c[:weight].to_f <= 0 ? 0.5 : c[:weight].to_f)
        {
          id: c[:id],
          final_score: relevance,
          reason: reason_for(c),
          matched_phrase: c[:matched_phrase],
          vec_score: c[:vec_score],
          weight: c[:weight],
          role: c[:role]
        }
      end

      ordered = scored.sort_by { |x| -x[:final_score] }

      filtered = []
      ordered.each do |row|
        product = Product.find_by(id: row[:id])
        next unless product
        sid = product.shop_id
        next if by_merchant[sid] >= merchant_cap
        by_merchant[sid] += 1
        filtered << row
        break if filtered.size >= 200
      end

      filtered
    end

    def self.normalize(x)
      x = x.to_f
      return 0.0 if x.nan? || x.infinite?
      [[x, 0.0].max, 1.0].min
    end

    def self.reason_for(c)
      return "Pairs with your pick" if c[:role].to_s == "complement"
      phr = c[:matched_phrase].to_s.downcase
      return "Budget option" if phr.include?("budget")
      return "Close to the styles you viewed" if phr.present?
      "Matches your recent interest"
    end
  end
end
