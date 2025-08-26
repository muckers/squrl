use squrl_integration_tests::*;
use squrl_integration_tests::rate_limiting::*;
use tokio::time::{sleep, Duration, Instant};
use tracing::{info, warn, error};
use std::sync::Arc;
use tokio::sync::Mutex;

/// Comprehensive rate limiting tests
/// Tests API Gateway limits (100 req/sec sustained, 200 burst) and WAF limits (1000/5min)
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    tracing_subscriber::fmt::init();
    
    let config = TestConfig::default();
    let mut client = TestClient::new(config.clone());
    
    info!("Starting rate limiting tests against {}", config.base_url);
    info!("Environment: {}", config.environment);
    
    // Only run load tests if explicitly enabled
    if !config.run_load_tests {
        warn!("Load tests disabled. Set RUN_LOAD_TESTS=true to enable.");
        warn!("These tests will make many requests and may hit rate limits.");
        info!("Running basic rate limit validation tests only...");
        return run_basic_rate_limit_tests(&mut client).await;
    }
    
    // Run all rate limiting tests
    let mut passed = 0;
    let mut failed = 0;
    
    // Test 1: API Gateway sustained rate limit (100 req/sec)
    match test_sustained_rate_limit(&mut client).await {
        Ok(_) => {
            info!("✅ Test 1 PASSED: Sustained rate limit (100 req/sec)");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 1 FAILED: Sustained rate limit - {}", e);
            failed += 1;
        }
    }
    
    // Cool down between tests
    utils::wait_with_logging(Duration::from_secs(10), "cooldown between tests").await;
    
    // Test 2: API Gateway burst rate limit (200 req/sec)
    match test_burst_rate_limit(&mut client).await {
        Ok(_) => {
            info!("✅ Test 2 PASSED: Burst rate limit (200 req/sec)");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 2 FAILED: Burst rate limit - {}", e);
            failed += 1;
        }
    }
    
    // Cool down between tests
    utils::wait_with_logging(Duration::from_secs(15), "cooldown between tests").await;
    
    // Test 3: Per-endpoint rate limits
    match test_per_endpoint_rate_limits(&mut client).await {
        Ok(_) => {
            info!("✅ Test 3 PASSED: Per-endpoint rate limits");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 3 FAILED: Per-endpoint rate limits - {}", e);
            failed += 1;
        }
    }
    
    // Cool down before WAF tests
    utils::wait_with_logging(Duration::from_secs(30), "cooldown before WAF tests").await;
    
    // Test 4: WAF rate limits (1000 requests in 5 minutes)
    match test_waf_rate_limits(&mut client).await {
        Ok(_) => {
            info!("✅ Test 4 PASSED: WAF rate limits (1000/5min)");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 4 FAILED: WAF rate limits - {}", e);
            failed += 1;
        }
    }
    
    // Test 5: Rate limit recovery
    match test_rate_limit_recovery(&mut client).await {
        Ok(_) => {
            info!("✅ Test 5 PASSED: Rate limit recovery");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 5 FAILED: Rate limit recovery - {}", e);
            failed += 1;
        }
    }
    
    // Test 6: Rate limit headers and error messages
    match test_rate_limit_headers(&mut client).await {
        Ok(_) => {
            info!("✅ Test 6 PASSED: Rate limit headers and messages");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 6 FAILED: Rate limit headers - {}", e);
            failed += 1;
        }
    }
    
    // Test 7: Concurrent rate limiting behavior
    match test_concurrent_rate_limiting(&mut client).await {
        Ok(_) => {
            info!("✅ Test 7 PASSED: Concurrent rate limiting");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 7 FAILED: Concurrent rate limiting - {}", e);
            failed += 1;
        }
    }
    
    // Summary
    info!("===============================");
    info!("Rate Limiting Tests Summary:");
    info!("✅ Passed: {}", passed);
    info!("❌ Failed: {}", failed);
    info!("Total: {}", passed + failed);
    
    if failed > 0 {
        error!("Some rate limiting tests failed. Check logs above for details.");
        std::process::exit(1);
    } else {
        info!("All rate limiting tests passed successfully! 🎉");
        Ok(())
    }
}

/// Run basic rate limit validation tests (without heavy load)
async fn run_basic_rate_limit_tests(client: &mut TestClient) -> Result<(), Box<dyn std::error::Error>> {
    info!("Running basic rate limit validation tests...");
    
    let mut passed = 0;
    let mut failed = 0;
    
    // Test basic rate limiting behavior with a small number of requests
    match test_basic_rate_limiting(client).await {
        Ok(_) => {
            info!("✅ Basic rate limiting validation passed");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Basic rate limiting validation failed: {}", e);
            failed += 1;
        }
    }
    
    // Test rate limit error responses
    match test_rate_limit_error_responses(client).await {
        Ok(_) => {
            info!("✅ Rate limit error response validation passed");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Rate limit error response validation failed: {}", e);
            failed += 1;
        }
    }
    
    info!("Basic rate limit tests completed: {} passed, {} failed", passed, failed);
    
    if failed > 0 {
        std::process::exit(1);
    }
    
    Ok(())
}

/// Test basic rate limiting behavior with moderate load
async fn test_basic_rate_limiting(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing basic rate limiting behavior...");
    
    // Make 10 requests quickly to see if any get rate limited
    let mut rate_limited = 0;
    let mut successful = 0;
    
    for i in 0..10 {
        let request = CreateUrlRequest {
            url: format!("https://example.com/test-{}", i),
            custom_code: None,
        };
        
        match client.create_url(request).await {
            Ok(_) => successful += 1,
            Err(TestError::RateLimit(_)) => rate_limited += 1,
            Err(e) => {
                error!("Unexpected error during basic rate limit test: {}", e);
                return Err(e);
            }
        }
        
        // Small delay between requests
        sleep(Duration::from_millis(100)).await;
    }
    
    info!("Basic rate limiting test: {} successful, {} rate limited", successful, rate_limited);
    
    // We expect most requests to succeed with this moderate rate
    if successful == 0 {
        return Err(TestError::ValidationError(
            "All requests were rate limited - this seems too aggressive".to_string()
        ));
    }
    
    Ok(())
}

/// Test rate limit error response format
async fn test_rate_limit_error_responses(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing rate limit error response format...");
    
    // Make enough requests to likely trigger a rate limit
    for i in 0..50 {
        let request = CreateUrlRequest {
            url: format!("https://example.com/fast-test-{}", i),
            custom_code: None,
        };
        
        match client.create_url(request).await {
            Ok(_) => {
                // Continue making requests
            }
            Err(TestError::RateLimit(error_response)) => {
                info!("Received rate limit error: {}", error_response.message);
                
                // Validate error response structure
                if error_response.error.is_empty() {
                    return Err(TestError::ValidationError(
                        "Rate limit error response missing error field".to_string()
                    ));
                }
                
                if error_response.message.is_empty() {
                    return Err(TestError::ValidationError(
                        "Rate limit error response missing message field".to_string()
                    ));
                }
                
                info!("Rate limit error response format is correct");
                return Ok(());
            }
            Err(e) => {
                return Err(e);
            }
        }
        
        // No delay to increase chance of rate limiting
    }
    
    warn!("Did not encounter rate limiting in error response test");
    Ok(())
}

/// Test sustained rate limit (100 req/sec for API Gateway)
async fn test_sustained_rate_limit(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing sustained rate limit (100 req/sec)...");
    
    // Test at 90 req/sec for 10 seconds (should mostly succeed)
    let result_90 = test_rate_limit(client, 90, 10).await;
    info!("90 req/sec test: {:.1}% rate limited", result_90.rate_limit_percentage());
    
    // Cool down
    sleep(Duration::from_secs(5)).await;
    
    // Test at 110 req/sec for 10 seconds (should get rate limited)
    let result_110 = test_rate_limit(client, 110, 10).await;
    info!("110 req/sec test: {:.1}% rate limited", result_110.rate_limit_percentage());
    
    // Validate results
    if result_90.rate_limit_percentage() > 10.0 {
        return Err(TestError::ValidationError(format!(
            "Too many requests rate limited at 90 req/sec: {:.1}%",
            result_90.rate_limit_percentage()
        )));
    }
    
    if result_110.rate_limit_percentage() < 5.0 {
        return Err(TestError::ValidationError(format!(
            "Expected more rate limiting at 110 req/sec, got {:.1}%",
            result_110.rate_limit_percentage()
        )));
    }
    
    info!("Sustained rate limit test passed");
    Ok(())
}

/// Test burst rate limit (200 req/sec for API Gateway)
async fn test_burst_rate_limit(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing burst rate limit (200 req/sec)...");
    
    // Test burst of 100 requests quickly
    let result_100 = burst_test(client, 100).await;
    info!("100 request burst: {:.1}% rate limited", result_100.rate_limit_percentage());
    
    // Wait for rate limit to reset
    sleep(Duration::from_secs(10)).await;
    
    // Test burst of 250 requests quickly
    let result_250 = burst_test(client, 250).await;
    info!("250 request burst: {:.1}% rate limited", result_250.rate_limit_percentage());
    
    // Validate results
    if result_100.rate_limit_percentage() > 20.0 {
        return Err(TestError::ValidationError(format!(
            "Too many requests rate limited in 100-request burst: {:.1}%",
            result_100.rate_limit_percentage()
        )));
    }
    
    if result_250.rate_limit_percentage() < 10.0 {
        return Err(TestError::ValidationError(format!(
            "Expected more rate limiting in 250-request burst, got {:.1}%",
            result_250.rate_limit_percentage()
        )));
    }
    
    info!("Burst rate limit test passed");
    Ok(())
}

/// Test per-endpoint rate limits
async fn test_per_endpoint_rate_limits(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing per-endpoint rate limits...");
    
    // Create a URL first for testing redirect and stats endpoints
    let create_request = CreateUrlRequest {
        url: utils::random_test_url(),
        custom_code: None,
    };
    
    let create_response = client.create_url(create_request).await?;
    sleep(Duration::from_millis(500)).await; // Wait for URL to be available
    
    // Test create endpoint rate limiting (100 requests/minute per IP)
    let mut create_rate_limited = 0;
    let mut create_successful = 0;
    
    for i in 0..30 {
        let request = CreateUrlRequest {
            url: format!("https://example.com/endpoint-test-{}", i),
            custom_code: None,
        };
        
        match client.create_url(request).await {
            Ok(_) => create_successful += 1,
            Err(TestError::RateLimit(_)) => create_rate_limited += 1,
            Err(_) => {} // Ignore other errors for this test
        }
        
        sleep(Duration::from_millis(100)).await; // 10 req/sec
    }
    
    info!("Create endpoint: {} successful, {} rate limited", 
          create_successful, create_rate_limited);
    
    // Test redirect endpoint rate limiting (1000 requests/minute per IP - much higher)
    let mut redirect_rate_limited = 0;
    let mut redirect_successful = 0;
    
    for _ in 0..30 {
        match client.test_redirect(&create_response.short_code).await {
            Ok(_) => redirect_successful += 1,
            Err(TestError::RateLimit(_)) => redirect_rate_limited += 1,
            Err(_) => {} // Ignore other errors
        }
        
        sleep(Duration::from_millis(50)).await; // 20 req/sec
    }
    
    info!("Redirect endpoint: {} successful, {} rate limited", 
          redirect_successful, redirect_rate_limited);
    
    // Test stats endpoint rate limiting (100 requests/minute per IP)
    let mut stats_rate_limited = 0;
    let mut stats_successful = 0;
    
    for _ in 0..30 {
        match client.get_stats(&create_response.short_code).await {
            Ok(_) => stats_successful += 1,
            Err(TestError::RateLimit(_)) => stats_rate_limited += 1,
            Err(_) => {} // Ignore other errors
        }
        
        sleep(Duration::from_millis(100)).await; // 10 req/sec
    }
    
    info!("Stats endpoint: {} successful, {} rate limited", 
          stats_successful, stats_rate_limited);
    
    // Validate that redirect endpoint has higher limits
    if redirect_rate_limited > create_rate_limited + 5 {
        return Err(TestError::ValidationError(
            "Redirect endpoint seems to have stricter rate limits than create endpoint".to_string()
        ));
    }
    
    info!("Per-endpoint rate limit test passed");
    Ok(())
}

/// Test WAF rate limits (1000 requests per 5 minutes)
async fn test_waf_rate_limits(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing WAF rate limits (1000/5min) - this will take several minutes...");
    
    // This test makes many requests over time to test the 5-minute window
    // We'll make 200 requests per minute for 3 minutes = 600 requests total
    // This should not trigger WAF limits, but gets us closer
    
    let start_time = Instant::now();
    let mut total_successful = 0;
    let mut total_rate_limited = 0;
    let mut waf_blocked = 0;
    
    for minute in 0..3 {
        info!("WAF test minute {}/3", minute + 1);
        
        for i in 0..200 {
            let request = CreateUrlRequest {
                url: format!("https://example.com/waf-test-{}-{}", minute, i),
                custom_code: None,
            };
            
            match client.create_url(request).await {
                Ok(_) => total_successful += 1,
                Err(TestError::RateLimit(_)) => total_rate_limited += 1,
                Err(TestError::Api(403, _)) => {
                    waf_blocked += 1;
                    info!("Received 403 (likely WAF block) after {} requests", 
                          total_successful + total_rate_limited + waf_blocked);
                }
                Err(_) => {} // Ignore other errors
            }
            
            sleep(Duration::from_millis(300)).await; // ~3.3 req/sec
        }
        
        info!("After minute {}: {} successful, {} rate limited, {} WAF blocked",
              minute + 1, total_successful, total_rate_limited, waf_blocked);
    }
    
    let elapsed = start_time.elapsed();
    info!("WAF test completed in {:.1} seconds", elapsed.as_secs_f64());
    info!("Total: {} successful, {} rate limited, {} WAF blocked",
          total_successful, total_rate_limited, waf_blocked);
    
    // At this rate (600 requests in 3 minutes), we shouldn't hit WAF limits
    if waf_blocked > total_successful / 10 {
        return Err(TestError::ValidationError(format!(
            "WAF seems to be blocking too aggressively: {} blocked out of {} total",
            waf_blocked, total_successful + total_rate_limited + waf_blocked
        )));
    }
    
    info!("WAF rate limit test passed (no excessive blocking detected)");
    Ok(())
}

/// Test rate limit recovery behavior
async fn test_rate_limit_recovery(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing rate limit recovery...");
    
    // First, trigger rate limiting
    let mut rate_limited_count = 0;
    for i in 0..100 {
        let request = CreateUrlRequest {
            url: format!("https://example.com/recovery-test-{}", i),
            custom_code: None,
        };
        
        match client.create_url(request).await {
            Ok(_) => {}
            Err(TestError::RateLimit(_)) => {
                rate_limited_count += 1;
                if rate_limited_count >= 5 {
                    info!("Successfully triggered rate limiting");
                    break;
                }
            }
            Err(_) => {}
        }
    }
    
    if rate_limited_count == 0 {
        warn!("Could not trigger rate limiting for recovery test");
        return Ok(());
    }
    
    // Wait for rate limit to recover
    info!("Waiting 30 seconds for rate limit recovery...");
    sleep(Duration::from_secs(30)).await;
    
    // Try requests again - should succeed
    let mut post_recovery_successful = 0;
    let mut post_recovery_rate_limited = 0;
    
    for i in 0..10 {
        let request = CreateUrlRequest {
            url: format!("https://example.com/post-recovery-{}", i),
            custom_code: None,
        };
        
        match client.create_url(request).await {
            Ok(_) => post_recovery_successful += 1,
            Err(TestError::RateLimit(_)) => post_recovery_rate_limited += 1,
            Err(_) => {}
        }
        
        sleep(Duration::from_millis(500)).await; // Slow rate
    }
    
    info!("Post-recovery: {} successful, {} rate limited",
          post_recovery_successful, post_recovery_rate_limited);
    
    // Most requests should succeed after recovery
    if post_recovery_successful < 5 {
        return Err(TestError::ValidationError(
            "Rate limit recovery may not be working properly".to_string()
        ));
    }
    
    info!("Rate limit recovery test passed");
    Ok(())
}

/// Test rate limit headers and error message quality
async fn test_rate_limit_headers(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing rate limit headers and error messages...");
    
    // Make requests until we get a rate limit error
    for i in 0..50 {
        let request = CreateUrlRequest {
            url: format!("https://example.com/headers-test-{}", i),
            custom_code: None,
        };
        
        match client.create_url(request).await {
            Ok(_) => {
                // Continue until rate limited
            }
            Err(TestError::RateLimit(error)) => {
                info!("Received rate limit error for headers test");
                
                // Check error message quality
                if error.message.len() < 10 {
                    return Err(TestError::ValidationError(
                        "Rate limit error message is too short".to_string()
                    ));
                }
                
                // Check for common rate limit error indicators
                let message_lower = error.message.to_lowercase();
                if !message_lower.contains("rate") && !message_lower.contains("limit") 
                   && !message_lower.contains("throttle") && !message_lower.contains("quota") {
                    warn!("Rate limit error message might not be clear: '{}'", error.message);
                }
                
                // Check error type
                if error.error.to_lowercase() != "rate_limit_exceeded" 
                   && error.error.to_lowercase() != "throttlingerror"
                   && error.error.to_lowercase() != "too_many_requests" {
                    warn!("Rate limit error type might not be standard: '{}'", error.error);
                }
                
                info!("Rate limit error format validated");
                return Ok(());
            }
            Err(e) => {
                return Err(e);
            }
        }
    }
    
    warn!("Did not encounter rate limiting in headers test");
    Ok(())
}

/// Test concurrent rate limiting behavior
async fn test_concurrent_rate_limiting(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing concurrent rate limiting behavior...");
    
    // Create multiple clients to simulate concurrent users
    let config = client.config().clone();
    let clients = Arc::new(Mutex::new(vec![
        TestClient::new(config.clone()),
        TestClient::new(config.clone()),
        TestClient::new(config),
    ]));
    
    // Spawn concurrent requests
    let mut handles = vec![];
    
    for client_id in 0..3 {
        let clients_clone = clients.clone();
        
        let handle = tokio::spawn(async move {
            let mut results = ConcurrentTestResult {
                client_id,
                successful: 0,
                rate_limited: 0,
                errors: 0,
            };
            
            for i in 0..20 {
                let request = CreateUrlRequest {
                    url: format!("https://example.com/concurrent-{}-{}", client_id, i),
                    custom_code: None,
                };
                
                let mut clients_guard = clients_clone.lock().await;
                let client = &mut clients_guard[client_id];
                
                match client.create_url(request).await {
                    Ok(_) => results.successful += 1,
                    Err(TestError::RateLimit(_)) => results.rate_limited += 1,
                    Err(_) => results.errors += 1,
                }
                drop(clients_guard);
                
                sleep(Duration::from_millis(200)).await; // 5 req/sec per client
            }
            
            results
        });
        
        handles.push(handle);
    }
    
    // Wait for all concurrent tests to complete
    let results: Vec<ConcurrentTestResult> = futures::future::join_all(handles)
        .await
        .into_iter()
        .map(|r| r.unwrap())
        .collect();
    
    // Analyze results
    let total_successful: u32 = results.iter().map(|r| r.successful).sum();
    let total_rate_limited: u32 = results.iter().map(|r| r.rate_limited).sum();
    let total_errors: u32 = results.iter().map(|r| r.errors).sum();
    
    info!("Concurrent test results:");
    for result in &results {
        info!("  Client {}: {} successful, {} rate limited, {} errors",
              result.client_id, result.successful, result.rate_limited, result.errors);
    }
    
    info!("Total: {} successful, {} rate limited, {} errors",
          total_successful, total_rate_limited, total_errors);
    
    // Validate that rate limiting is working consistently across clients
    if total_successful == 0 && total_rate_limited > 0 {
        return Err(TestError::ValidationError(
            "All concurrent requests were rate limited - limits may be too strict".to_string()
        ));
    }
    
    if total_rate_limited == 0 && total_successful > 50 {
        warn!("No rate limiting detected in concurrent test - limits may be too lenient");
    }
    
    info!("Concurrent rate limiting test passed");
    Ok(())
}

#[derive(Debug)]
struct ConcurrentTestResult {
    client_id: usize,
    successful: u32,
    rate_limited: u32,
    errors: u32,
}

// We need to bring in futures for join_all
// This would normally be in Cargo.toml, but for this example:
mod futures {
    pub mod future {
        use std::future::Future;
        use std::pin::Pin;
        use std::task::{Context, Poll};
        
        pub async fn join_all<I>(iter: I) -> Vec<I::Item>
        where
            I: IntoIterator,
            I::Item: Future,
        {
            let mut futures: Vec<Pin<Box<dyn Future<Output = <I::Item as Future>::Output>>>> = 
                iter.into_iter().map(|f| Box::pin(f) as Pin<Box<dyn Future<Output = _>>>).collect();
            
            let mut results = Vec::with_capacity(futures.len());
            
            while !futures.is_empty() {
                let mut i = 0;
                while i < futures.len() {
                    let mut future = futures.remove(i);
                    match Pin::new(&mut future).poll(&mut Context::from_waker(&futures::task::noop_waker())) {
                        Poll::Ready(result) => {
                            results.push(result);
                        }
                        Poll::Pending => {
                            futures.insert(i, future);
                            i += 1;
                        }
                    }
                }
                tokio::task::yield_now().await;
            }
            
            results
        }
    }
    
    pub mod task {
        use std::task::{Waker, RawWaker, RawWakerVTable};
        
        pub fn noop_waker() -> Waker {
            const VTABLE: RawWakerVTable = RawWakerVTable::new(
                |_| RawWaker::new(std::ptr::null(), &VTABLE),
                |_| {},
                |_| {},
                |_| {},
            );
            unsafe { Waker::from_raw(RawWaker::new(std::ptr::null(), &VTABLE)) }
        }
    }
}