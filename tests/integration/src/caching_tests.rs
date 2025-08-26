use squrl_integration_tests::*;
use tokio::time::{sleep, Duration, Instant};
use tracing::{info, warn, error};
use std::collections::HashMap;

/// Comprehensive CloudFront caching tests
/// Tests cache behavior, TTL validation, and cache hit/miss rates
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    tracing_subscriber::fmt::init();
    
    let config = TestConfig::default();
    let mut client = TestClient::new(config.clone());
    
    info!("Starting caching tests against CloudFront URL: {}", config.cloudfront_url);
    info!("API Base URL: {}", config.base_url);
    info!("Environment: {}", config.environment);
    
    // Run all caching tests
    let mut passed = 0;
    let mut failed = 0;
    
    // Test 1: Basic cache behavior
    match test_basic_cache_behavior(&mut client).await {
        Ok(_) => {
            info!("✅ Test 1 PASSED: Basic cache behavior");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 1 FAILED: Basic cache behavior - {}", e);
            failed += 1;
        }
    }
    
    // Test 2: Cache headers validation
    match test_cache_headers(&mut client).await {
        Ok(_) => {
            info!("✅ Test 2 PASSED: Cache headers validation");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 2 FAILED: Cache headers validation - {}", e);
            failed += 1;
        }
    }
    
    // Test 3: Cache TTL behavior
    match test_cache_ttl_behavior(&mut client).await {
        Ok(_) => {
            info!("✅ Test 3 PASSED: Cache TTL behavior");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 3 FAILED: Cache TTL behavior - {}", e);
            failed += 1;
        }
    }
    
    // Test 4: Different endpoints caching behavior
    match test_endpoint_specific_caching(&mut client).await {
        Ok(_) => {
            info!("✅ Test 4 PASSED: Endpoint-specific caching");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 4 FAILED: Endpoint-specific caching - {}", e);
            failed += 1;
        }
    }
    
    // Test 5: Cache invalidation behavior
    match test_cache_invalidation(&mut client).await {
        Ok(_) => {
            info!("✅ Test 5 PASSED: Cache invalidation behavior");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 5 FAILED: Cache invalidation behavior - {}", e);
            failed += 1;
        }
    }
    
    // Test 6: Cache hit rate measurement
    match test_cache_hit_rate(&mut client).await {
        Ok(_) => {
            info!("✅ Test 6 PASSED: Cache hit rate measurement");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 6 FAILED: Cache hit rate measurement - {}", e);
            failed += 1;
        }
    }
    
    // Test 7: Cache behavior under load
    match test_cache_under_load(&mut client).await {
        Ok(_) => {
            info!("✅ Test 7 PASSED: Cache behavior under load");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 7 FAILED: Cache behavior under load - {}", e);
            failed += 1;
        }
    }
    
    // Test 8: Geographic cache distribution
    match test_geographic_cache_behavior(&mut client).await {
        Ok(_) => {
            info!("✅ Test 8 PASSED: Geographic cache behavior");
            passed += 1;
        }
        Err(e) => {
            warn!("⚠️ Test 8 FAILED: Geographic cache behavior - {} (may need multiple regions)", e);
            failed += 1;
        }
    }
    
    // Summary
    info!("===============================");
    info!("Caching Tests Summary:");
    info!("✅ Passed: {}", passed);
    info!("❌ Failed: {}", failed);
    info!("Total: {}", passed + failed);
    
    if failed > 0 {
        error!("Some caching tests failed. Check logs above for details.");
        std::process::exit(1);
    } else {
        info!("All caching tests passed successfully! 🎉");
        Ok(())
    }
}

/// Test basic cache behavior - cache miss followed by cache hit
async fn test_basic_cache_behavior(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing basic cache behavior...");
    
    // Create a URL first
    let create_request = CreateUrlRequest {
        url: utils::random_test_url(),
        custom_code: None,
    };
    
    let create_response = client.create_url(create_request).await?;
    info!("Created URL for cache test: {}", create_response.short_code);
    
    // Wait for URL to be available
    sleep(Duration::from_millis(500)).await;
    
    // First request - should be cache miss
    let start_time = Instant::now();
    let cache_info_1 = client.check_cache_headers(&create_response.short_code).await?;
    let first_response_time = start_time.elapsed();
    
    info!("First request (cache miss):");
    info!("  Response time: {}ms", first_response_time.as_millis());
    info!("  Cache status: {:?}", cache_info_1.cloudfront_cache_status);
    info!("  Cache control: {:?}", cache_info_1.cache_control);
    
    // Wait a moment for cache to be populated
    sleep(Duration::from_millis(200)).await;
    
    // Second request - should be cache hit
    let start_time = Instant::now();
    let cache_info_2 = client.check_cache_headers(&create_response.short_code).await?;
    let second_response_time = start_time.elapsed();
    
    info!("Second request (should be cache hit):");
    info!("  Response time: {}ms", second_response_time.as_millis());
    info!("  Cache status: {:?}", cache_info_2.cloudfront_cache_status);
    info!("  Age header: {:?}", cache_info_2.age);
    
    // Validate cache behavior
    if let Some(ref cache_status) = cache_info_2.cloudfront_cache_status {
        if cache_status.contains("Hit") {
            info!("✓ Cache hit detected in second request");
        } else if cache_status.contains("Miss") {
            warn!("Second request was still a cache miss - cache may not be working as expected");
        } else {
            info!("Cache status: {} (may indicate caching is working)", cache_status);
        }
    } else {
        warn!("No CloudFront cache status header found");
    }
    
    // Generally, cached responses should be faster, but this can vary
    if second_response_time < first_response_time && second_response_time.as_millis() < 50 {
        info!("✓ Second request was significantly faster (likely cached)");
    }
    
    info!("Basic cache behavior test completed");
    Ok(())
}

/// Test cache headers are properly set
async fn test_cache_headers(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing cache headers validation...");
    
    // Create a URL for testing
    let create_request = CreateUrlRequest {
        url: utils::random_test_url(),
        custom_code: None,
    };
    
    let create_response = client.create_url(create_request).await?;
    sleep(Duration::from_millis(500)).await;
    
    // Check cache headers
    let cache_info = client.check_cache_headers(&create_response.short_code).await?;
    
    info!("Cache headers analysis:");
    info!("  Cache-Control: {:?}", cache_info.cache_control);
    info!("  CloudFront Status: {:?}", cache_info.cloudfront_cache_status);
    info!("  Age: {:?}", cache_info.age);
    info!("  Expires: {:?}", cache_info.expires);
    
    // Validate essential cache headers
    if cache_info.cache_control.is_none() && cache_info.expires.is_none() {
        return Err(TestError::ValidationError(
            "No cache control headers found (Cache-Control or Expires)".to_string()
        ));
    }
    
    // Check for CloudFront-specific headers
    if cache_info.cloudfront_cache_status.is_none() {
        warn!("No CloudFront cache status header found - may not be going through CloudFront");
    }
    
    // Validate cache control directives
    if let Some(ref cache_control) = cache_info.cache_control {
        if cache_control.contains("no-cache") || cache_control.contains("no-store") {
            return Err(TestError::ValidationError(
                "Cache control prevents caching - this may not be desired for redirects".to_string()
            ));
        }
        
        if cache_control.contains("max-age") {
            info!("✓ Cache control includes max-age directive");
        } else {
            warn!("Cache control doesn't specify max-age");
        }
    }
    
    info!("Cache headers validation completed");
    Ok(())
}

/// Test cache TTL behavior over time
async fn test_cache_ttl_behavior(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing cache TTL behavior (this test takes longer)...");
    
    // Create a URL for testing
    let create_request = CreateUrlRequest {
        url: utils::random_test_url(),
        custom_code: None,
    };
    
    let create_response = client.create_url(create_request).await?;
    sleep(Duration::from_millis(500)).await;
    
    // First request to populate cache
    let cache_info_1 = client.check_cache_headers(&create_response.short_code).await?;
    info!("Initial cache request completed");
    
    // Wait and check age progression
    let test_intervals = vec![5, 10, 20]; // seconds
    let mut previous_age = cache_info_1.age.unwrap_or(0);
    
    for interval in test_intervals {
        info!("Waiting {} seconds to test age progression...", interval);
        sleep(Duration::from_secs(interval)).await;
        
        let cache_info = client.check_cache_headers(&create_response.short_code).await?;
        
        if let Some(age) = cache_info.age {
            info!("After {} seconds - Age header: {} seconds", interval, age);
            
            // Age should be increasing (allowing for some timing variation)
            if age >= previous_age {
                info!("✓ Cache age is progressing correctly");
                previous_age = age;
            } else {
                warn!("Cache age decreased - cache may have been refreshed");
            }
            
            // Check cache status
            if let Some(ref status) = cache_info.cloudfront_cache_status {
                info!("  Cache status: {}", status);
            }
        } else {
            warn!("No age header found after {} seconds", interval);
        }
    }
    
    info!("Cache TTL behavior test completed");
    Ok(())
}

/// Test caching behavior for different endpoints
async fn test_endpoint_specific_caching(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing endpoint-specific caching behavior...");
    
    // Create a URL for testing
    let create_request = CreateUrlRequest {
        url: utils::random_test_url(),
        custom_code: None,
    };
    
    let create_response = client.create_url(create_request).await?;
    sleep(Duration::from_millis(500)).await;
    
    // Test redirect endpoint caching (should be cached)
    info!("Testing redirect endpoint caching...");
    let redirect_cache_1 = client.check_cache_headers(&create_response.short_code).await?;
    sleep(Duration::from_millis(200)).await;
    let redirect_cache_2 = client.check_cache_headers(&create_response.short_code).await?;
    
    info!("Redirect endpoint cache behavior:");
    info!("  First request: {:?}", redirect_cache_1.cloudfront_cache_status);
    info!("  Second request: {:?}", redirect_cache_2.cloudfront_cache_status);
    
    // Test stats endpoint caching (may or may not be cached)
    info!("Testing stats endpoint caching behavior...");
    let start_time = Instant::now();
    let _stats_1 = client.get_stats(&create_response.short_code).await?;
    let stats_time_1 = start_time.elapsed();
    
    sleep(Duration::from_millis(200)).await;
    
    let start_time = Instant::now();
    let _stats_2 = client.get_stats(&create_response.short_code).await?;
    let stats_time_2 = start_time.elapsed();
    
    info!("Stats endpoint response times:");
    info!("  First request: {}ms", stats_time_1.as_millis());
    info!("  Second request: {}ms", stats_time_2.as_millis());
    
    // Create endpoint should not be cached (POST requests)
    info!("Create endpoint should not cache POST requests (by design)");
    
    // Validate redirect caching
    if let (Some(ref status1), Some(ref status2)) = 
        (&redirect_cache_1.cloudfront_cache_status, &redirect_cache_2.cloudfront_cache_status) {
        if status1.contains("Miss") && status2.contains("Hit") {
            info!("✓ Redirect endpoint caching working correctly");
        } else if status2.contains("Hit") {
            info!("✓ Redirect endpoint showing cache hits");
        } else {
            warn!("Redirect endpoint caching behavior unclear: {} -> {}", status1, status2);
        }
    }
    
    info!("Endpoint-specific caching test completed");
    Ok(())
}

/// Test cache invalidation scenarios
async fn test_cache_invalidation(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing cache invalidation behavior...");
    
    // Create a URL for testing
    let test_url = utils::random_test_url();
    let create_request = CreateUrlRequest {
        url: test_url.clone(),
        custom_code: None,
    };
    
    let create_response = client.create_url(create_request).await?;
    sleep(Duration::from_millis(500)).await;
    
    // Make several requests to ensure caching
    info!("Populating cache with multiple requests...");
    for i in 0..3 {
        let cache_info = client.check_cache_headers(&create_response.short_code).await?;
        info!("Request {}: Cache status: {:?}", i + 1, cache_info.cloudfront_cache_status);
        sleep(Duration::from_millis(200)).await;
    }
    
    // Test cache behavior with URL that doesn't exist (404 responses)
    info!("Testing 404 response caching...");
    let nonexistent_code = "nonexistent123";
    
    // First 404 request
    let start_time = Instant::now();
    match client.test_redirect(nonexistent_code).await {
        Err(TestError::NotFound) => {
            let first_404_time = start_time.elapsed();
            info!("First 404 response time: {}ms", first_404_time.as_millis());
        }
        _ => {
            return Err(TestError::ValidationError(
                "Expected 404 for nonexistent code".to_string()
            ));
        }
    }
    
    sleep(Duration::from_millis(200)).await;
    
    // Second 404 request (should also be 404, may be cached)
    let start_time = Instant::now();
    match client.test_redirect(nonexistent_code).await {
        Err(TestError::NotFound) => {
            let second_404_time = start_time.elapsed();
            info!("Second 404 response time: {}ms", second_404_time.as_millis());
            
            if second_404_time < first_404_time && second_404_time.as_millis() < 50 {
                info!("✓ 404 responses may be cached (faster second response)");
            } else {
                info!("404 responses timing: {} -> {} ms", 
                     first_404_time.as_millis(), second_404_time.as_millis());
            }
        }
        _ => {
            return Err(TestError::ValidationError(
                "Expected 404 for nonexistent code on second try".to_string()
            ));
        }
    }
    
    info!("Cache invalidation test completed");
    Ok(())
}

/// Test cache hit rate over multiple requests
async fn test_cache_hit_rate(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing cache hit rate measurement...");
    
    // Create multiple URLs for testing
    let mut short_codes = Vec::new();
    
    for i in 0..5 {
        let create_request = CreateUrlRequest {
            url: format!("https://example.com/cache-hit-test-{}", i),
            custom_code: None,
        };
        
        let response = client.create_url(create_request).await?;
        short_codes.push(response.short_code);
        sleep(Duration::from_millis(100)).await; // Avoid rate limiting
    }
    
    // Wait for URLs to be available
    sleep(Duration::from_millis(1000)).await;
    
    // Make initial requests to populate cache
    info!("Populating cache with initial requests...");
    for (i, short_code) in short_codes.iter().enumerate() {
        let cache_info = client.check_cache_headers(short_code).await?;
        info!("Initial request {}: {:?}", i + 1, cache_info.cloudfront_cache_status);
        sleep(Duration::from_millis(200)).await;
    }
    
    // Wait for cache to be fully populated
    sleep(Duration::from_millis(1000)).await;
    
    // Test cache hit rate with repeated requests
    let mut cache_stats = CacheStats::new();
    
    info!("Testing cache hit rate with multiple requests...");
    for round in 0..3 {
        info!("Cache hit test round {}/3", round + 1);
        
        for short_code in &short_codes {
            let cache_info = client.check_cache_headers(short_code).await?;
            cache_stats.record_request(&cache_info);
            sleep(Duration::from_millis(100)).await;
        }
        
        // Also test some of the same URLs multiple times
        for short_code in short_codes.iter().take(2) {
            let cache_info = client.check_cache_headers(short_code).await?;
            cache_stats.record_request(&cache_info);
            sleep(Duration::from_millis(100)).await;
        }
    }
    
    // Analyze cache hit rate
    let hit_rate = cache_stats.hit_rate();
    info!("Cache hit rate analysis:");
    info!("  Total requests: {}", cache_stats.total_requests());
    info!("  Cache hits: {}", cache_stats.hits);
    info!("  Cache misses: {}", cache_stats.misses);
    info!("  Unknown status: {}", cache_stats.unknown);
    info!("  Hit rate: {:.1}%", hit_rate * 100.0);
    
    // Validate hit rate - should be reasonably high for repeated requests
    if hit_rate < 0.3 {
        warn!("Cache hit rate is quite low: {:.1}% - caching may not be optimal", hit_rate * 100.0);
    } else if hit_rate > 0.7 {
        info!("✓ Good cache hit rate: {:.1}%", hit_rate * 100.0);
    } else {
        info!("Moderate cache hit rate: {:.1}%", hit_rate * 100.0);
    }
    
    info!("Cache hit rate test completed");
    Ok(())
}

/// Test cache behavior under load
async fn test_cache_under_load(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing cache behavior under load...");
    
    // Create a URL for load testing
    let create_request = CreateUrlRequest {
        url: utils::random_test_url(),
        custom_code: None,
    };
    
    let create_response = client.create_url(create_request).await?;
    sleep(Duration::from_millis(500)).await;
    
    // Make many rapid requests to test cache under load
    let request_count = 20;
    let mut response_times = Vec::new();
    let mut cache_stats = CacheStats::new();
    
    info!("Making {} rapid requests to test cache under load...", request_count);
    
    for i in 0..request_count {
        let start_time = Instant::now();
        let cache_info = client.check_cache_headers(&create_response.short_code).await?;
        let response_time = start_time.elapsed();
        
        response_times.push(response_time);
        cache_stats.record_request(&cache_info);
        
        if i % 5 == 0 {
            info!("Request {}: {}ms, Status: {:?}", 
                  i + 1, response_time.as_millis(), cache_info.cloudfront_cache_status);
        }
        
        // Small delay to avoid overwhelming the system
        sleep(Duration::from_millis(50)).await;
    }
    
    // Analyze performance under load
    let avg_response_time: f64 = response_times.iter()
        .map(|d| d.as_millis() as f64)
        .sum::<f64>() / response_times.len() as f64;
    
    let min_time = response_times.iter().min().unwrap().as_millis();
    let max_time = response_times.iter().max().unwrap().as_millis();
    
    info!("Cache performance under load:");
    info!("  Total requests: {}", request_count);
    info!("  Average response time: {:.1}ms", avg_response_time);
    info!("  Min response time: {}ms", min_time);
    info!("  Max response time: {}ms", max_time);
    info!("  Cache hit rate: {:.1}%", cache_stats.hit_rate() * 100.0);
    
    // Validate performance
    if avg_response_time > 1000.0 {
        return Err(TestError::ValidationError(
            format!("Average response time too high under load: {:.1}ms", avg_response_time)
        ));
    }
    
    if max_time > 5000 {
        warn!("Some requests took over 5 seconds: {}ms", max_time);
    }
    
    // Check for consistent caching
    if cache_stats.hit_rate() < 0.5 {
        warn!("Cache hit rate under load is low: {:.1}%", cache_stats.hit_rate() * 100.0);
    } else {
        info!("✓ Good cache performance under load");
    }
    
    info!("Cache under load test completed");
    Ok(())
}

/// Test geographic cache distribution (limited without multiple regions)
async fn test_geographic_cache_behavior(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing geographic cache behavior...");
    
    // Create a URL for testing
    let create_request = CreateUrlRequest {
        url: utils::random_test_url(),
        custom_code: None,
    };
    
    let create_response = client.create_url(create_request).await?;
    sleep(Duration::from_millis(500)).await;
    
    // Make requests and analyze any geographic indicators
    let cache_info = client.check_cache_headers(&create_response.short_code).await?;
    
    info!("Geographic cache analysis:");
    info!("  Cache status: {:?}", cache_info.cloudfront_cache_status);
    
    // Look for CloudFront edge location indicators
    if let Some(ref status) = cache_info.cloudfront_cache_status {
        if status.contains("from") || status.contains("cloudfront") {
            info!("CloudFront cache status indicates edge processing: {}", status);
        }
        
        // Different CloudFront edge locations might be indicated in the cache status
        info!("✓ CloudFront cache headers present, indicating edge distribution");
    } else {
        warn!("No CloudFront cache status headers - may not be using CloudFront");
    }
    
    // Test with custom headers to simulate different geographic origins
    let mut custom_headers = HashMap::new();
    custom_headers.insert("CloudFront-Viewer-Country".to_string(), "US".to_string());
    custom_headers.insert("CloudFront-Viewer-City".to_string(), "Seattle".to_string());
    
    // Make a request with geographic simulation headers
    match client.raw_request("GET", &format!("/{}", create_response.short_code), None, Some(custom_headers)).await {
        Ok((status, _)) => {
            if status == 301 || status == 302 {
                info!("✓ Geographic header test successful (redirect received)");
            } else {
                warn!("Unexpected status with geographic headers: {}", status);
            }
        }
        Err(e) => {
            warn!("Geographic header test failed: {}", e);
        }
    }
    
    info!("Geographic cache behavior test completed (limited without multiple regions)");
    Ok(())
}

/// Cache statistics tracking
#[derive(Debug, Default)]
struct CacheStats {
    hits: u32,
    misses: u32,
    unknown: u32,
}

impl CacheStats {
    fn new() -> Self {
        Self::default()
    }
    
    fn record_request(&mut self, cache_info: &CacheInfo) {
        if let Some(ref status) = cache_info.cloudfront_cache_status {
            if status.contains("Hit") {
                self.hits += 1;
            } else if status.contains("Miss") {
                self.misses += 1;
            } else {
                self.unknown += 1;
            }
        } else {
            self.unknown += 1;
        }
    }
    
    fn total_requests(&self) -> u32 {
        self.hits + self.misses + self.unknown
    }
    
    fn hit_rate(&self) -> f64 {
        let total = self.total_requests();
        if total == 0 {
            0.0
        } else {
            self.hits as f64 / total as f64
        }
    }
}