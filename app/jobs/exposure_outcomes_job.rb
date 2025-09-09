class ExposureOutcomesJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("[ExposureOutcomesJob] Running hourly exposure outcomes computation.")
    
    start_time = Time.current
    window_start = start_time.beginning_of_hour
    window_end = start_time.end_of_hour
    
    # Process events from the last hour
    process_hourly_window(window_start, window_end)
    
    duration = Time.current - start_time
    Rails.logger.info("[ExposureOutcomesJob] Completed in #{duration.round(2)}s")
  end

  private

  def process_hourly_window(window_start, window_end)
    # Get all feed items from the window period
    feed_items = get_feed_items_in_window(window_start, window_end)
    
    if feed_items.empty?
      Rails.logger.info("[ExposureOutcomesJob] No feed items found in window #{window_start} - #{window_end}")
      return
    end

    Rails.logger.info("[ExposureOutcomesJob] Processing #{feed_items.count} feed items")
    
    # Process each feed item to compute outcomes
    processed_count = 0
    error_count = 0
    
    feed_items.find_each(batch_size: 100) do |feed_item|
      begin
        process_feed_item(feed_item, window_start, window_end)
        processed_count += 1
      rescue => e
        error_count += 1
        Rails.logger.error "[ExposureOutcomesJob] Error processing feed_item #{feed_item.id}: #{e.message}"
      end
    end
    
    # Log completion stats
    Rails.logger.info("[ExposureOutcomesJob] Processed: #{processed_count}, Errors: #{error_count}")
    
    # Update join success metrics
    update_join_success_metrics(processed_count, feed_items.count)
  end

  def get_feed_items_in_window(window_start, window_end)
    FeedItem.joins(:feed)
           .where(feeds: { created_at: window_start..window_end })
           .includes(:feed)
  end

  def process_feed_item(feed_item, window_start, window_end)
    feed = feed_item.feed
    
    # Find matching events for this exposure
    events = find_matching_events(feed, feed_item, window_start, window_end)
    
    # Compute attribution flags and timestamps
    attribution_data = compute_attribution(events, feed_item)
    
    # Calculate item weight
    item_weight = calculate_item_weight(attribution_data, feed_item.position)
    
    # Upsert exposure outcome
    upsert_exposure_outcome(feed, feed_item, attribution_data, item_weight, window_start, window_end)
  end

  def find_matching_events(feed, feed_item, window_start, window_end)
    # Find events that match this exposure within attribution windows
    Event.where(
      session_id: feed.session_id,
      timestamp_utc: window_start..window_end
    ).where(
      "payload->>'product_id' = ?", feed_item.product_id.to_s
    ).where(
      "payload->>'feed_id' = ?", feed.feed_uid
    ).order(:timestamp_utc)
  end

  def compute_attribution(events, feed_item)
    attribution = {
      clicked_5m: false,
      atc_30m: false,
      purchased_24h: false,
      first_click_at: nil,
      first_atc_at: nil,
      first_purchase_at: nil
    }
    
    events.each do |event|
      case event.event_name
      when 'product_click'
        if !attribution[:clicked_5m] && within_window?(event.timestamp_utc, feed_item.created_at, 5.minutes)
          attribution[:clicked_5m] = true
          attribution[:first_click_at] = event.timestamp_utc
        end
      when 'add_to_cart'
        if !attribution[:atc_30m] && within_window?(event.timestamp_utc, feed_item.created_at, 30.minutes)
          attribution[:atc_30m] = true
          attribution[:first_atc_at] = event.timestamp_utc
        end
      when 'purchase'
        if !attribution[:purchased_24h] && within_window?(event.timestamp_utc, feed_item.created_at, 24.hours)
          attribution[:purchased_24h] = true
          attribution[:first_purchase_at] = event.timestamp_utc
        end
      end
    end
    
    attribution
  end

  def within_window?(event_time, exposure_time, window)
    event_time >= exposure_time && event_time <= exposure_time + window
  end

  def calculate_item_weight(attribution_data, position)
    # Formula: (1×clicked_5m + 5×atc_30m + 20×purchased_24h) × position_discount
    base_weight = 0
    base_weight += 1 if attribution_data[:clicked_5m]
    base_weight += 5 if attribution_data[:atc_30m]
    base_weight += 20 if attribution_data[:purchased_24h]
    
    # Position discount: 1/log2(2 + position)
    position_discount = 1.0 / Math.log2(2 + position)
    
    (base_weight * position_discount).round(4)
  end

  def upsert_exposure_outcome(feed, feed_item, attribution_data, item_weight, window_start, window_end)
    # Use upsert to handle duplicates
    ExposureOutcome.upsert(
      {
        feed_uid: feed.feed_uid,
        plan_id: feed.plan_id,
        section: feed_item.section,
        product_id: feed_item.product_id,
        position: feed_item.position,
        clicked_5m: attribution_data[:clicked_5m],
        atc_30m: attribution_data[:atc_30m],
        purchased_24h: attribution_data[:purchased_24h],
        item_weight_w1: item_weight,
        window_start: window_start,
        window_end: window_end,
        created_at: Time.current,
        updated_at: Time.current
      },
      unique_by: [:feed_uid, :plan_id, :section, :product_id, :position],
      on_duplicate: Arel.sql(<<~SQL)
        clicked_5m = EXCLUDED.clicked_5m,
        atc_30m = EXCLUDED.atc_30m,
        purchased_24h = EXCLUDED.purchased_24h,
        item_weight_w1 = EXCLUDED.item_weight_w1,
        window_start = EXCLUDED.window_start,
        window_end = EXCLUDED.window_end,
        updated_at = EXCLUDED.updated_at
      SQL
    )
  end

  def update_join_success_metrics(processed_count, total_count)
    return if total_count.zero?
    
    success_rate = (processed_count.to_f / total_count * 100).round(2)
    
    # Store metrics for monitoring
    Rails.cache.write("etl:exposure_outcomes:join_success_rate", success_rate, expires_in: 1.hour)
    Rails.cache.write("etl:exposure_outcomes:last_run", Time.current, expires_in: 1.hour)
    
    # Alert if join success rate is too low
    if success_rate < 95
      Rails.logger.warn "[ExposureOutcomesJob] Low join success rate: #{success_rate}% (threshold: 95%)"
      # In production, this would trigger an alert
    end
  end
end


