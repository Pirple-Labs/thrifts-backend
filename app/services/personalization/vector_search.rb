# frozen_string_literal: true
module Personalization
  class VectorSearch
    TOPK_PER_PHRASE = (ENV["TOPK_PER_PHRASE"] || 30).to_i

    # query_pack: { "queries":[{"phrase","category","weight","role"}...],
    #               "constraints":{"pickup_only":true,"region":"Nairobi"} }
    # returns: [{ id:, matched_phrase:, vec_score:, weight:, role: }]
    def self.call(query_pack:, limit:)
      queries = Array(query_pack["queries"])
      cons    = query_pack["constraints"] || {}
      pickup  = !!cons["pickup_only"]
      region  = cons["region"].to_s

      phrases = queries.map { |q| q["phrase"].to_s }.reject(&:blank?)
      return [] if phrases.empty?

      vectors = Embeddings::OpenAIClient.embed(phrases)

      buckets = []
      queries.each_with_index do |q, i|
        vec = vectors[i]
        next unless vec

        rows = ActiveRecord::Base.connection.exec_query(ann_sql(vec, q, pickup, region))
        rows.each do |r|
          buckets << {
            id:             r["product_id"],
            matched_phrase: q["phrase"].to_s,
            vec_score:      r["similarity"].to_f, # 1 - cosine distance
            weight:         (q["weight"] || 1.0),
            role:           q["role"]
          }
        end
      end

      # dedupe by product, keep best weighted score
      merged = {}
      buckets.each do |c|
        k = c[:id].to_s
        score = c[:vec_score].to_f * c[:weight].to_f
        merged[k] = c.merge(score:) if !merged[k] || score > merged[k][:score]
      end

      merged.values
            .sort_by { |h| -h[:score] }
            .first(limit)
            .map { |h| h.slice(:id, :matched_phrase, :vec_score, :weight, :role) }
    end

    # Direct vector KNN (for image search or custom query vectors)
    def self.by_vector(vector:, limit: TOPK_PER_PHRASE, constraints: {})
      pickup = !!constraints["pickup_only"]
      region = constraints["region"].to_s
      rows = ActiveRecord::Base.connection.exec_query(ann_sql(vector, { "category" => nil }, pickup, region))
      rows.first(limit).map { |r| { id: r["product_id"], vec_score: r["similarity"].to_f } }
    end

    # --- SQL helpers ---
    def self.ann_sql(vec, q, pickup, region)
      <<~SQL
        SELECT p.id AS product_id,
               #{cosine_similarity_sql(vec)} AS similarity
        FROM product_embeddings pe
        JOIN products p ON p.id = pe.product_id
        JOIN shops s ON s.id = p.shop_id
        WHERE p.stock > 0
          AND p.moderation_status = 'approved'
          #{pickup ? "AND s.pickup_agent = TRUE" : ""}
          #{category_filter_sql(q["category"])}
          #{region_filter_sql(region)}
        ORDER BY similarity DESC
        LIMIT #{TOPK_PER_PHRASE}
      SQL
    end

    def self.cosine_similarity_sql(vec)
      # Calculate cosine similarity in SQL since we don't have pgvector
      # This is a simplified version - in production you'd use pgvector
      vec_str = vec.map { |x| format("%.6f", x) }.join(",")
      
      # Calculate dot product and magnitudes for cosine similarity
      <<~SQL
        (
          SELECT 
            CASE 
              WHEN magnitude1 = 0 OR magnitude2 = 0 THEN 0
              ELSE dot_product / (magnitude1 * magnitude2)
            END
          FROM (
            SELECT 
              SUM(pe_val * vec_val) as dot_product,
              SQRT(SUM(pe_val * pe_val)) as magnitude1,
              SQRT(SUM(vec_val * vec_val)) as magnitude2
            FROM (
              SELECT 
                CAST(pe_val AS FLOAT) as pe_val,
                CAST(vec_val AS FLOAT) as vec_val
              FROM (
                SELECT 
                  unnest(string_to_array(pe.embedding, ',')) as pe_val,
                  unnest(ARRAY[#{vec_str}]) as vec_val
              ) t
            ) t2
          ) t3
        )
      SQL
    end

    def self.category_filter_sql(cat)
      return "" if cat.blank?
      if (rec = Category.find_by(name: cat.to_s))
        "AND p.category_id = #{rec.id}"
      else
        ""
      end
    end

    def self.region_filter_sql(region)
      return "" if region.blank?
      ActiveRecord::Base.sanitize_sql_array(["AND s.location = ?", region])
    end
  end
end
