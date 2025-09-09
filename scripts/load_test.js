// Load testing script for Thrifts API using k6
// Target: 100 RPS sustained for 30 minutes
// Success criteria: p95 ≤ 1.0s, errors < 0.5%

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const feedLatency = new Trend('feed_latency');
const eventsLatency = new Trend('events_latency');
const errorRate = new Rate('error_rate');
const feedErrorRate = new Rate('feed_error_rate');
const eventsErrorRate = new Rate('events_error_rate');
const feedsGenerated = new Counter('feeds_generated');
const eventsPosted = new Counter('events_posted');

// Test configuration
export const options = {
  scenarios: {
    // Sustained load: 100 RPS for 30 minutes
    sustained_load: {
      executor: 'constant-rate',
      rate: 100,
      timeUnit: '1s',
      duration: '30m',
      preAllocatedVUs: 50,
      maxVUs: 100,
    },
    
    // Burst test: 200 RPS for 5 minutes  
    burst_test: {
      executor: 'constant-rate',
      rate: 200,
      timeUnit: '1s',
      duration: '5m',
      startTime: '30m',
      preAllocatedVUs: 100,
      maxVUs: 150,
    },
    
    // Events heavy load: 1000 events/s for 10 minutes
    events_heavy: {
      executor: 'constant-rate',
      rate: 1000,
      timeUnit: '1s',
      duration: '10m',
      startTime: '35m',
      preAllocatedVUs: 50,
      maxVUs: 100,
      exec: 'eventsOnly',
    }
  },
  
  thresholds: {
    // SLO targets
    'feed_latency': ['p(95)<1000'], // p95 ≤ 1.0s
    'events_latency': ['p(95)<500'], // Events should be faster
    'error_rate': ['rate<0.005'], // < 0.5% error rate
    'feed_error_rate': ['rate<0.005'],
    'events_error_rate': ['rate<0.005'],
    'http_req_duration': ['p(95)<1000'],
    'http_req_failed': ['rate<0.005'],
  }
};

// Test data generators
const regions = ['Nairobi', 'Mombasa', 'Kisumu', 'Nakuru', 'Eldoret'];
const pages = ['home', 'pdp', 'profile', 'cart', 'checkout'];
const searchTerms = ['dress', 'shoes', 'phone', 'laptop', 'jacket', 'bag', 'watch'];
const eventNames = [
  'page_view', 'product_impression', 'product_click', 'add_to_cart', 
  'search_performed', 'feed_impression'
];

function randomChoice(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function generateUserId() {
  return Math.floor(Math.random() * 10000) + 1;
}

function generateSessionId() {
  return `session_${Math.random().toString(36).substr(2, 9)}`;
}

function generateEventId() {
  return `event_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

// Base URL - adjust for your environment
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function() {
  // 70% feeds, 30% events to simulate realistic traffic
  if (Math.random() < 0.7) {
    testFeedGeneration();
  } else {
    testEventIngestion();
  }
  
  // Small random delay to simulate real user behavior
  sleep(Math.random() * 0.5);
}

// Test feed generation endpoint
function testFeedGeneration() {
  const sessionId = generateSessionId();
  const userId = Math.random() > 0.3 ? generateUserId() : null; // 70% authenticated
  const page = randomChoice(pages);
  const region = randomChoice(regions);
  
  // Base feed request
  let payload = {
    page: page,
    session_id: sessionId,
    region: region,
    limit: Math.floor(Math.random() * 20) + 10, // 10-30 items
  };
  
  if (userId) {
    payload.user_id = userId;
  }
  
  // 20% of requests include search
  if (Math.random() < 0.2) {
    if (Math.random() < 0.9) {
      // Text search
      payload.searchType = 'text';
      payload.searchTerm = randomChoice(searchTerms);
    } else {
      // Image search (simulated)
      payload.searchType = 'image';
      payload.imageUrl = 'https://res.cloudinary.com/demo/image/upload/sample.jpg';
    }
  }
  
  // 10% of requests have force_variant for A/B testing
  if (Math.random() < 0.1) {
    payload.force_variant = Math.random() < 0.5 ? 'control' : 'operator';
  }
  
  const startTime = Date.now();
  
  const response = http.post(`${BASE_URL}/api/feed/start`, JSON.stringify(payload), {
    headers: {
      'Content-Type': 'application/json',
    },
  });
  
  const duration = Date.now() - startTime;
  feedLatency.add(duration);
  
  const success = check(response, {
    'feed status is 200': (r) => r.status === 200,
    'feed has feed_id': (r) => {
      try {
        const data = JSON.parse(r.body);
        return data.feed_id && data.feed_id !== 'fallback';
      } catch (e) {
        return false;
      }
    },
    'feed has sections': (r) => {
      try {
        const data = JSON.parse(r.body);
        return Array.isArray(data.sections) && data.sections.length > 0;
      } catch (e) {
        return false;
      }
    },
    'feed has plan_id': (r) => {
      try {
        const data = JSON.parse(r.body);
        return data.plan_id && data.plan_id.length > 0;
      } catch (e) {
        return false;
      }
    },
    'feed response time < 2s': (r) => duration < 2000,
  });
  
  if (!success) {
    feedErrorRate.add(1);
    errorRate.add(1);
  } else {
    feedErrorRate.add(0);
    feedsGenerated.add(1);
    
    // Test pagination if feed was successful
    if (Math.random() < 0.3) { // 30% of feeds test pagination
      testFeedPagination(response);
    }
  }
}

// Test feed pagination
function testFeedPagination(feedResponse) {
  try {
    const feedData = JSON.parse(feedResponse.body);
    
    if (feedData.hasMore && feedData.cursor) {
      const paginationPayload = {
        feed_id: feedData.feed_id,
        cursor: feedData.cursor,
        limit: Math.floor(Math.random() * 15) + 5, // 5-20 items
      };
      
      const startTime = Date.now();
      
      const response = http.post(`${BASE_URL}/api/feed/next`, JSON.stringify(paginationPayload), {
        headers: {
          'Content-Type': 'application/json',
        },
      });
      
      const duration = Date.now() - startTime;
      feedLatency.add(duration);
      
      const success = check(response, {
        'pagination status is 200': (r) => r.status === 200,
        'pagination has products': (r) => {
          try {
            const data = JSON.parse(r.body);
            return data.sections && data.sections[0] && data.sections[0].products.length > 0;
          } catch (e) {
            return false;
          }
        },
      });
      
      if (!success) {
        feedErrorRate.add(1);
        errorRate.add(1);
      } else {
        feedErrorRate.add(0);
      }
    }
  } catch (e) {
    // Ignore pagination errors for malformed feed responses
  }
}

// Test event ingestion endpoint  
function testEventIngestion() {
  const sessionId = generateSessionId();
  const userId = Math.random() > 0.3 ? generateUserId() : null;
  const eventCount = Math.floor(Math.random() * 5) + 1; // 1-5 events per batch
  
  const events = [];
  for (let i = 0; i < eventCount; i++) {
    const event = {
      event_id: generateEventId(),
      session_id: sessionId,
      event_name: randomChoice(eventNames),
      page: randomChoice(pages),
      region: randomChoice(regions),
      timestamp_utc: new Date().toISOString(),
      payload: generateEventPayload(),
    };
    
    if (userId) {
      event.user_id = userId;
    }
    
    events.push(event);
  }
  
  const payload = {
    events: events,
    client_sent_at: new Date().toISOString(),
  };
  
  const startTime = Date.now();
  
  const response = http.post(`${BASE_URL}/api/events`, JSON.stringify(payload), {
    headers: {
      'Content-Type': 'application/json',
    },
  });
  
  const duration = Date.now() - startTime;
  eventsLatency.add(duration);
  
  const success = check(response, {
    'events status is 200': (r) => r.status === 200,
    'events accepted': (r) => {
      try {
        const data = JSON.parse(r.body);
        return data.accepted >= 0 && data.rejected >= 0;
      } catch (e) {
        return false;
      }
    },
    'events response time < 1s': (r) => duration < 1000,
  });
  
  if (!success) {
    eventsErrorRate.add(1);
    errorRate.add(1);
  } else {
    eventsErrorRate.add(0);
    eventsPosted.add(eventCount);
  }
}

// Events-only test function for high-volume scenario
export function eventsOnly() {
  testEventIngestion();
}

// Generate realistic event payload
function generateEventPayload() {
  const payloads = {
    page_view: {},
    product_impression: {
      feed_id: `feed_${Math.random().toString(36).substr(2, 9)}`,
      product_id: Math.floor(Math.random() * 1000) + 1,
      position: Math.floor(Math.random() * 20),
      section: 'grid',
    },
    product_click: {
      feed_id: `feed_${Math.random().toString(36).substr(2, 9)}`,
      product_id: Math.floor(Math.random() * 1000) + 1,
      position: Math.floor(Math.random() * 20),
    },
    add_to_cart: {
      product_id: Math.floor(Math.random() * 1000) + 1,
      quantity: Math.floor(Math.random() * 3) + 1,
      price_cents: Math.floor(Math.random() * 10000) + 1000,
    },
    search_performed: {
      search_term: randomChoice(searchTerms),
      search_type: 'text',
    },
    feed_impression: {
      feed_id: `feed_${Math.random().toString(36).substr(2, 9)}`,
      products: [
        Math.floor(Math.random() * 1000) + 1,
        Math.floor(Math.random() * 1000) + 1,
        Math.floor(Math.random() * 1000) + 1,
      ],
    },
  };
  
  return payloads[randomChoice(eventNames)] || {};
}

// Test teardown
export function teardown(data) {
  console.log('Load test completed');
  console.log(`Feeds generated: ${feedsGenerated.count}`);
  console.log(`Events posted: ${eventsPosted.count}`);
}
