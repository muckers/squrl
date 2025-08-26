use squrl_integration_tests::*;
use tokio::time::{sleep, Duration};
use tracing::{info, warn, error};

/// Comprehensive API functionality tests
/// Tests all three endpoints with various scenarios
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    tracing_subscriber::fmt::init();
    
    let config = TestConfig::default();
    let mut client = TestClient::new(config.clone());
    
    info!("Starting API functionality tests against {}", config.base_url);
    info!("Using CloudFront URL: {}", config.cloudfront_url);
    info!("Environment: {}", config.environment);
    
    // Run all API tests
    let mut passed = 0;
    let mut failed = 0;
    
    // Test 1: Basic URL creation
    match test_basic_url_creation(&mut client).await {
        Ok(_) => {
            info!("✅ Test 1 PASSED: Basic URL creation");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 1 FAILED: Basic URL creation - {}", e);
            failed += 1;
        }
    }
    
    // Test 2: Custom code creation
    match test_custom_code_creation(&mut client).await {
        Ok(_) => {
            info!("✅ Test 2 PASSED: Custom code creation");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 2 FAILED: Custom code creation - {}", e);
            failed += 1;
        }
    }
    
    // Test 3: URL deduplication
    match test_url_deduplication(&mut client).await {
        Ok(_) => {
            info!("✅ Test 3 PASSED: URL deduplication");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 3 FAILED: URL deduplication - {}", e);
            failed += 1;
        }
    }
    
    // Test 4: Redirect functionality
    match test_redirect_functionality(&mut client).await {
        Ok(_) => {
            info!("✅ Test 4 PASSED: Redirect functionality");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 4 FAILED: Redirect functionality - {}", e);
            failed += 1;
        }
    }
    
    // Test 5: Statistics endpoint
    match test_statistics_endpoint(&mut client).await {
        Ok(_) => {
            info!("✅ Test 5 PASSED: Statistics endpoint");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 5 FAILED: Statistics endpoint - {}", e);
            failed += 1;
        }
    }
    
    // Test 6: Error handling
    match test_error_handling(&mut client).await {
        Ok(_) => {
            info!("✅ Test 6 PASSED: Error handling");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 6 FAILED: Error handling - {}", e);
            failed += 1;
        }
    }
    
    // Test 7: Input validation
    match test_input_validation(&mut client).await {
        Ok(_) => {
            info!("✅ Test 7 PASSED: Input validation");
            passed += 1;
        }
        Err(e) => {
            error!("❌ Test 7 FAILED: Input validation - {}", e);
            failed += 1;
        }
    }
    
    // Test 8: CORS headers
    match test_cors_headers(&mut client).await {
        Ok(_) => {
            info!("✅ Test 8 PASSED: CORS headers");
            passed += 1;
        }
        Err(e) => {
            warn!("⚠️ Test 8 FAILED: CORS headers - {} (may not be critical)", e);
            failed += 1;
        }
    }
    
    // Summary
    info!("===============================");
    info!("API Tests Summary:");
    info!("✅ Passed: {}", passed);
    info!("❌ Failed: {}", failed);
    info!("Total: {}", passed + failed);
    
    if failed > 0 {
        error!("Some tests failed. Check logs above for details.");
        std::process::exit(1);
    } else {
        info!("All API tests passed successfully! 🎉");
        Ok(())
    }
}

/// Test basic URL creation functionality
async fn test_basic_url_creation(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing basic URL creation...");
    
    let test_url = utils::random_test_url();
    let request = CreateUrlRequest {
        url: test_url.clone(),
        custom_code: None,
    };
    
    let response = client.create_url(request).await?;
    
    // Validate response structure
    if response.short_code.is_empty() {
        return Err(TestError::ValidationError("Short code is empty".to_string()));
    }
    
    if response.short_url.is_empty() {
        return Err(TestError::ValidationError("Short URL is empty".to_string()));
    }
    
    if response.expires_at.is_empty() {
        return Err(TestError::ValidationError("Expires at is empty".to_string()));
    }
    
    // Validate short URL format
    if !utils::is_valid_url(&response.short_url) {
        return Err(TestError::ValidationError("Invalid short URL format".to_string()));
    }
    
    // Check that the short URL contains the short code
    if !response.short_url.contains(&response.short_code) {
        return Err(TestError::ValidationError(
            "Short URL doesn't contain short code".to_string(),
        ));
    }
    
    info!("Created short URL: {} -> {}", response.short_url, test_url);
    Ok(())
}

/// Test custom code creation
async fn test_custom_code_creation(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing custom code creation...");
    
    let test_url = utils::random_test_url();
    let custom_code = utils::random_custom_code();
    
    let request = CreateUrlRequest {
        url: test_url.clone(),
        custom_code: Some(custom_code.clone()),
    };
    
    let response = client.create_url(request).await?;
    
    // Validate that the response uses the custom code
    if response.short_code != custom_code {
        return Err(TestError::ValidationError(format!(
            "Expected custom code '{}', got '{}'",
            custom_code, response.short_code
        )));
    }
    
    // Try to create the same custom code again - should fail
    let duplicate_request = CreateUrlRequest {
        url: utils::random_test_url(),
        custom_code: Some(custom_code.clone()),
    };
    
    match client.create_url(duplicate_request).await {
        Ok(_) => {
            return Err(TestError::ValidationError(
                "Duplicate custom code was allowed".to_string(),
            ));
        }
        Err(TestError::Api(409, _)) => {
            info!("Correctly rejected duplicate custom code");
        }
        Err(e) => {
            return Err(TestError::ValidationError(format!(
                "Expected 409 conflict for duplicate code, got: {}",
                e
            )));
        }
    }
    
    info!("Custom code creation working correctly: {}", custom_code);
    Ok(())
}

/// Test URL deduplication (same URL should return same short code)
async fn test_url_deduplication(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing URL deduplication...");
    
    let test_url = utils::random_test_url();
    
    // Create first URL
    let request1 = CreateUrlRequest {
        url: test_url.clone(),
        custom_code: None,
    };
    
    let response1 = client.create_url(request1).await?;
    
    // Wait a moment to ensure different timestamps if they were different
    sleep(Duration::from_millis(100)).await;
    
    // Create same URL again
    let request2 = CreateUrlRequest {
        url: test_url.clone(),
        custom_code: None,
    };
    
    let response2 = client.create_url(request2).await?;
    
    // Should return the same short code
    if response1.short_code != response2.short_code {
        return Err(TestError::ValidationError(format!(
            "URL deduplication failed: {} != {}",
            response1.short_code, response2.short_code
        )));
    }
    
    info!("URL deduplication working: {} -> {}", test_url, response1.short_code);
    Ok(())
}

/// Test redirect functionality
async fn test_redirect_functionality(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing redirect functionality...");
    
    let test_url = utils::random_test_url();
    
    // First create a URL
    let create_request = CreateUrlRequest {
        url: test_url.clone(),
        custom_code: None,
    };
    
    let create_response = client.create_url(create_request).await?;
    
    // Wait a moment for the URL to be available
    sleep(Duration::from_millis(500)).await;
    
    // Test redirect
    let redirect_url = client.test_redirect(&create_response.short_code).await?;
    
    if redirect_url != test_url {
        return Err(TestError::ValidationError(format!(
            "Redirect URL mismatch: expected '{}', got '{}'",
            test_url, redirect_url
        )));
    }
    
    // Test non-existent short code
    match client.test_redirect("nonexistent123").await {
        Err(TestError::NotFound) => {
            info!("Correctly returned 404 for non-existent short code");
        }
        Ok(_) => {
            return Err(TestError::ValidationError(
                "Non-existent short code should return 404".to_string(),
            ));
        }
        Err(e) => {
            return Err(TestError::ValidationError(format!(
                "Expected 404 for non-existent code, got: {}",
                e
            )));
        }
    }
    
    info!("Redirect functionality working: {} -> {}", create_response.short_code, test_url);
    Ok(())
}

/// Test statistics endpoint
async fn test_statistics_endpoint(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing statistics endpoint...");
    
    let test_url = utils::random_test_url();
    
    // Create a URL
    let create_request = CreateUrlRequest {
        url: test_url.clone(),
        custom_code: None,
    };
    
    let create_response = client.create_url(create_request).await?;
    
    // Wait for URL to be available
    sleep(Duration::from_millis(500)).await;
    
    // Get initial stats
    let initial_stats = client.get_stats(&create_response.short_code).await?;
    
    // Validate stats structure
    if initial_stats.short_code != create_response.short_code {
        return Err(TestError::ValidationError(
            "Stats short code mismatch".to_string(),
        ));
    }
    
    if initial_stats.clicks > 0 {
        warn!("Initial click count is {} (expected 0)", initial_stats.clicks);
    }
    
    if initial_stats.created_at.is_empty() {
        return Err(TestError::ValidationError("Created at is empty".to_string()));
    }
    
    // Access the URL to increment click count
    client.test_redirect(&create_response.short_code).await?;
    
    // Wait for analytics to be processed
    sleep(Duration::from_millis(1000)).await;
    
    // Get updated stats
    let updated_stats = client.get_stats(&create_response.short_code).await?;
    
    // Click count might be updated (depends on analytics processing speed)
    if updated_stats.clicks < initial_stats.clicks {
        return Err(TestError::ValidationError(
            "Click count decreased".to_string(),
        ));
    }
    
    // Test stats for non-existent short code
    match client.get_stats("nonexistent123").await {
        Err(TestError::NotFound) => {
            info!("Correctly returned 404 for non-existent short code stats");
        }
        Ok(_) => {
            return Err(TestError::ValidationError(
                "Non-existent short code stats should return 404".to_string(),
            ));
        }
        Err(e) => {
            return Err(TestError::ValidationError(format!(
                "Expected 404 for non-existent code stats, got: {}",
                e
            )));
        }
    }
    
    info!("Statistics endpoint working: {} has {} clicks", 
          create_response.short_code, updated_stats.clicks);
    Ok(())
}

/// Test error handling and HTTP status codes
async fn test_error_handling(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing error handling...");
    
    // Test invalid JSON
    let (status, _) = client
        .raw_request(
            "POST",
            "/create",
            Some(serde_json::json!({"invalid": "json structure"})),
            None,
        )
        .await?;
    
    if status < 400 || status >= 500 {
        return Err(TestError::ValidationError(format!(
            "Expected 4xx error for invalid JSON, got {}",
            status
        )));
    }
    
    // Test missing required fields
    let (status, _) = client
        .raw_request("POST", "/create", Some(serde_json::json!({})), None)
        .await?;
    
    if status < 400 || status >= 500 {
        return Err(TestError::ValidationError(format!(
            "Expected 4xx error for missing fields, got {}",
            status
        )));
    }
    
    // Test invalid URL
    let (status, _) = client
        .raw_request(
            "POST",
            "/create",
            Some(serde_json::json!({"url": "not-a-valid-url"})),
            None,
        )
        .await?;
    
    if status < 400 || status >= 500 {
        return Err(TestError::ValidationError(format!(
            "Expected 4xx error for invalid URL, got {}",
            status
        )));
    }
    
    // Test unsupported HTTP method
    let (status, _) = client.raw_request("PATCH", "/create", None, None).await?;
    
    if status != 405 {
        return Err(TestError::ValidationError(format!(
            "Expected 405 for unsupported method, got {}",
            status
        )));
    }
    
    info!("Error handling working correctly");
    Ok(())
}

/// Test input validation edge cases
async fn test_input_validation(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing input validation...");
    
    // Test extremely long URL
    let long_url = format!("https://example.com/{}", "x".repeat(2000));
    let (status, _) = client
        .raw_request(
            "POST",
            "/create",
            Some(serde_json::json!({"url": long_url})),
            None,
        )
        .await?;
    
    if status < 400 || status >= 500 {
        return Err(TestError::ValidationError(format!(
            "Expected 4xx error for extremely long URL, got {}",
            status
        )));
    }
    
    // Test custom code with invalid characters
    let (status, _) = client
        .raw_request(
            "POST",
            "/create",
            Some(serde_json::json!({
                "url": "https://example.com",
                "custom_code": "invalid@code!"
            })),
            None,
        )
        .await?;
    
    if status < 400 || status >= 500 {
        return Err(TestError::ValidationError(format!(
            "Expected 4xx error for invalid custom code, got {}",
            status
        )));
    }
    
    // Test custom code that's too short
    let (status, _) = client
        .raw_request(
            "POST",
            "/create",
            Some(serde_json::json!({
                "url": "https://example.com",
                "custom_code": "ab"
            })),
            None,
        )
        .await?;
    
    if status < 400 || status >= 500 {
        return Err(TestError::ValidationError(format!(
            "Expected 4xx error for too short custom code, got {}",
            status
        )));
    }
    
    // Test custom code that's too long
    let (status, _) = client
        .raw_request(
            "POST",
            "/create",
            Some(serde_json::json!({
                "url": "https://example.com",
                "custom_code": "verylongcustomcodethatexceedsthelimit"
            })),
            None,
        )
        .await?;
    
    if status < 400 || status >= 500 {
        return Err(TestError::ValidationError(format!(
            "Expected 4xx error for too long custom code, got {}",
            status
        )));
    }
    
    info!("Input validation working correctly");
    Ok(())
}

/// Test CORS headers (important for browser access)
async fn test_cors_headers(client: &mut TestClient) -> Result<(), TestError> {
    info!("Testing CORS headers...");
    
    let headers = [
        ("Origin", "https://example.com"),
        ("Access-Control-Request-Method", "POST"),
        ("Access-Control-Request-Headers", "Content-Type"),
    ]
    .iter()
    .map(|(k, v)| (k.to_string(), v.to_string()))
    .collect();
    
    // Test OPTIONS preflight request
    let (status, response) = client.raw_request("OPTIONS", "/create", None, Some(headers)).await?;
    
    // OPTIONS should be successful (200) or at least not a server error
    if status >= 500 {
        return Err(TestError::ValidationError(format!(
            "OPTIONS request failed with status {}",
            status
        )));
    }
    
    // Look for CORS headers in the response (this is a basic check)
    info!("CORS preflight response status: {}", status);
    info!("CORS response body: {}", response);
    
    info!("CORS headers test completed (may need manual verification)");
    Ok(())
}