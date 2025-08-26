// Artillery test helper functions for Squrl load testing

const crypto = require('crypto');

// Generate a random custom code for testing
function generateCustomCode(context, events, done) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  context.vars.customCode = result;
  return done();
}

// Generate a random short code for testing (simulating existing codes)
function generateRandomShortCode(context, events, done) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  context.vars.randomShortCode = result;
  return done();
}

// Verify URL deduplication (check if short codes match)
function verifyDeduplication(context, events, done) {
  const first = context.vars.firstShortCode;
  const second = context.vars.secondShortCode;
  
  if (first && second) {
    if (first === second) {
      // Successful deduplication
      events.emit('counter', 'deduplication.success', 1);
    } else {
      // Deduplication failed
      events.emit('counter', 'deduplication.failure', 1);
    }
  } else {
    // Missing data
    events.emit('counter', 'deduplication.missing_data', 1);
  }
  
  return done();
}

// Select a random seeded URL for mixed workload testing
function selectRandomSeedUrl(context, events, done) {
  // Pick one of the pre-seeded URLs (1-50)
  const seedIndex = Math.floor(Math.random() * 50) + 1;
  const seedVariable = `seedShortCode${seedIndex}`;
  
  // Check if the seed URL exists in context
  if (context.vars[seedVariable]) {
    context.vars.selectedShortCode = context.vars[seedVariable];
  } else {
    // Fallback to a generated code if seed doesn't exist
    generateRandomShortCode(context, events, () => {
      context.vars.selectedShortCode = context.vars.randomShortCode;
    });
  }
  
  return done();
}

// Track response metrics
function trackResponseMetrics(requestParams, response, context, ee, next) {
  // Track response times by endpoint
  const path = requestParams.url || '';
  const method = requestParams.method || 'GET';
  const statusCode = response.statusCode;
  const responseTime = response.timings?.end || 0;
  
  // Emit custom metrics
  if (path.includes('/create')) {
    ee.emit('counter', 'create.requests', 1);
    ee.emit('histogram', 'create.response_time', responseTime);
    
    if (statusCode >= 200 && statusCode < 300) {
      ee.emit('counter', 'create.success', 1);
    } else if (statusCode === 429) {
      ee.emit('counter', 'create.rate_limited', 1);
    } else if (statusCode === 409) {
      ee.emit('counter', 'create.duplicate', 1);
    }
  } else if (path.includes('/stats/')) {
    ee.emit('counter', 'stats.requests', 1);
    ee.emit('histogram', 'stats.response_time', responseTime);
    
    if (statusCode === 200) {
      ee.emit('counter', 'stats.success', 1);
    } else if (statusCode === 404) {
      ee.emit('counter', 'stats.not_found', 1);
    } else if (statusCode === 429) {
      ee.emit('counter', 'stats.rate_limited', 1);
    }
  } else if (method === 'GET' && !path.includes('/stats/')) {
    // Likely a redirect request
    ee.emit('counter', 'redirect.requests', 1);
    ee.emit('histogram', 'redirect.response_time', responseTime);
    
    if (statusCode === 301 || statusCode === 302) {
      ee.emit('counter', 'redirect.success', 1);
      
      // Track cache headers if present
      const cacheHeader = response.headers['x-cache'] || response.headers['cf-cache-status'];
      if (cacheHeader) {
        if (cacheHeader.toLowerCase().includes('hit')) {
          ee.emit('counter', 'cache.hit', 1);
        } else if (cacheHeader.toLowerCase().includes('miss')) {
          ee.emit('counter', 'cache.miss', 1);
        }
      }
    } else if (statusCode === 404) {
      ee.emit('counter', 'redirect.not_found', 1);
    } else if (statusCode === 429) {
      ee.emit('counter', 'redirect.rate_limited', 1);
    }
  }
  
  // Track WAF blocking
  if (statusCode === 403) {
    ee.emit('counter', 'waf.blocked', 1);
  }
  
  // Track general rate limiting
  if (statusCode === 429) {
    ee.emit('counter', 'rate_limit.total', 1);
  }
  
  return next();
}

// Generate test data for URL creation
function generateTestUrl(context, events, done) {
  const domains = ['example.com', 'test.org', 'demo.net', 'sample.io'];
  const paths = ['page', 'article', 'blog', 'product', 'content', 'news'];
  
  const domain = domains[Math.floor(Math.random() * domains.length)];
  const path = paths[Math.floor(Math.random() * paths.length)];
  const id = Math.floor(Math.random() * 100000);
  const timestamp = Date.now();
  
  context.vars.testUrl = `https://${domain}/${path}-${id}-${timestamp}`;
  
  return done();
}

// Validate response structure
function validateCreateResponse(requestParams, response, context, ee, next) {
  if (response.statusCode === 200) {
    try {
      const body = JSON.parse(response.body);
      
      // Validate required fields
      const requiredFields = ['short_code', 'short_url', 'expires_at'];
      const missingFields = requiredFields.filter(field => !body[field]);
      
      if (missingFields.length > 0) {
        ee.emit('counter', 'validation.missing_fields', 1);
        console.warn(`Missing fields in create response: ${missingFields.join(', ')}`);
      } else {
        ee.emit('counter', 'validation.complete_response', 1);
      }
      
      // Validate short URL format
      if (body.short_url && !body.short_url.startsWith('http')) {
        ee.emit('counter', 'validation.invalid_url_format', 1);
      }
      
      // Store short code for potential reuse
      if (body.short_code) {
        context.vars.lastCreatedCode = body.short_code;
      }
      
    } catch (e) {
      ee.emit('counter', 'validation.json_parse_error', 1);
    }
  }
  
  return next();
}

// Validate redirect response
function validateRedirectResponse(requestParams, response, context, ee, next) {
  if (response.statusCode === 301 || response.statusCode === 302) {
    const location = response.headers['location'];
    
    if (!location) {
      ee.emit('counter', 'validation.missing_location_header', 1);
    } else if (!location.startsWith('http')) {
      ee.emit('counter', 'validation.invalid_redirect_url', 1);
    } else {
      ee.emit('counter', 'validation.valid_redirect', 1);
    }
  }
  
  return next();
}

// Generate realistic user agent strings
function generateUserAgent(context, events, done) {
  const userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Android 11; Mobile; rv:89.0) Gecko/89.0 Firefox/89.0'
  ];
  
  context.vars.userAgent = userAgents[Math.floor(Math.random() * userAgents.length)];
  return done();
}

// Performance monitoring function
function monitorPerformance(requestParams, response, context, ee, next) {
  const responseTime = response.timings?.end || 0;
  
  // Track slow responses
  if (responseTime > 1000) {
    ee.emit('counter', 'performance.slow_response', 1);
  }
  
  if (responseTime > 5000) {
    ee.emit('counter', 'performance.very_slow_response', 1);
  }
  
  // Track fast responses (likely cached)
  if (responseTime < 100) {
    ee.emit('counter', 'performance.fast_response', 1);
  }
  
  return next();
}

module.exports = {
  generateCustomCode,
  generateRandomShortCode,
  verifyDeduplication,
  selectRandomSeedUrl,
  trackResponseMetrics,
  generateTestUrl,
  validateCreateResponse,
  validateRedirectResponse,
  generateUserAgent,
  monitorPerformance
};