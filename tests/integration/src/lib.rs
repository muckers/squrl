use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, Instant};
use tokio::time::sleep;
use url::Url;

/// Configuration for integration tests
#[derive(Debug, Clone)]
pub struct TestConfig {
    /// Base URL for the API (e.g., https://api.squrl.dev)
    pub base_url: String,
    /// CloudFront distribution URL (e.g., https://squrl.dev)
    pub cloudfront_url: String,
    /// Environment name (dev, staging, prod)
    pub environment: String,
    /// Whether to run load tests
    pub run_load_tests: bool,
    /// Maximum request rate for load tests (requests per second)
    pub max_request_rate: u32,
    /// Test timeout in seconds
    pub timeout_seconds: u64,
}

impl Default for TestConfig {
    fn default() -> Self {
        Self {
            base_url: std::env::var("API_BASE_URL")
                .unwrap_or_else(|_| "https://api-dev.squrl.dev".to_string()),
            cloudfront_url: std::env::var("CLOUDFRONT_URL")
                .unwrap_or_else(|_| "https://squrl-dev.squrl.dev".to_string()),
            environment: std::env::var("TEST_ENV").unwrap_or_else(|_| "dev".to_string()),
            run_load_tests: std::env::var("RUN_LOAD_TESTS")
                .map(|v| v.to_lowercase() == "true")
                .unwrap_or(false),
            max_request_rate: std::env::var("MAX_REQUEST_RATE")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(100),
            timeout_seconds: std::env::var("TEST_TIMEOUT_SECONDS")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(30),
        }
    }
}

/// Request models matching the API specification
#[derive(Debug, Serialize)]
pub struct CreateUrlRequest {
    pub url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub custom_code: Option<String>,
}

/// Response models matching the API specification
#[derive(Debug, Deserialize)]
pub struct CreateUrlResponse {
    pub short_url: String,
    pub short_code: String,
    pub expires_at: String,
}

#[derive(Debug, Deserialize)]
pub struct StatsResponse {
    pub short_code: String,
    pub clicks: u64,
    pub created_at: String,
    pub expires_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ErrorResponse {
    pub error: String,
    pub message: String,
    #[serde(default)]
    pub details: Option<serde_json::Value>,
}

/// Test client with built-in rate limiting and error handling
pub struct TestClient {
    client: Client,
    config: TestConfig,
    request_history: Vec<RequestRecord>,
}

#[derive(Debug, Clone)]
pub struct RequestRecord {
    pub timestamp: Instant,
    pub method: String,
    pub path: String,
    pub status: u16,
    pub response_time_ms: u64,
    pub ip_address: Option<String>,
}

impl TestClient {
    pub fn new(config: TestConfig) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(config.timeout_seconds))
            .build()
            .expect("Failed to create HTTP client");

        Self {
            client,
            config,
            request_history: Vec::new(),
        }
    }

    pub fn config(&self) -> &TestConfig {
        &self.config
    }

    /// Create a shortened URL
    pub async fn create_url(
        &mut self,
        request: CreateUrlRequest,
    ) -> Result<CreateUrlResponse, TestError> {
        let start = Instant::now();
        let url = format!("{}/create", self.config.base_url);

        let response = self
            .client
            .post(&url)
            .json(&request)
            .send()
            .await
            .map_err(TestError::Http)?;

        let status = response.status().as_u16();
        self.record_request("POST", "/create", status, start.elapsed());

        match response.status().as_u16() {
            200..=299 => {
                let response_body: CreateUrlResponse =
                    response.json().await.map_err(TestError::Parsing)?;
                Ok(response_body)
            }
            429 => {
                let error_body: ErrorResponse =
                    response.json().await.map_err(TestError::Parsing)?;
                Err(TestError::RateLimit(error_body))
            }
            _ => {
                let error_body: ErrorResponse = response
                    .json()
                    .await
                    .unwrap_or_else(|_| ErrorResponse {
                        error: "UnknownError".to_string(),
                        message: format!("HTTP {}", status),
                        details: None,
                    });
                Err(TestError::Api(status, error_body))
            }
        }
    }

    /// Test redirect functionality
    pub async fn test_redirect(&mut self, short_code: &str) -> Result<String, TestError> {
        let start = Instant::now();
        let url = format!("{}/{}", self.config.cloudfront_url, short_code);

        // Use a client that doesn't follow redirects to test the redirect response
        let no_redirect_client = Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .timeout(Duration::from_secs(self.config.timeout_seconds))
            .build()
            .map_err(TestError::Http)?;

        let response = no_redirect_client
            .get(&url)
            .send()
            .await
            .map_err(TestError::Http)?;

        let status = response.status().as_u16();
        self.record_request("GET", &format!("/{}", short_code), status, start.elapsed());

        match status {
            301 | 302 => {
                if let Some(location) = response.headers().get("location") {
                    Ok(location.to_str().unwrap_or("").to_string())
                } else {
                    Err(TestError::MissingRedirectLocation)
                }
            }
            404 => Err(TestError::NotFound),
            429 => {
                let error_body: ErrorResponse =
                    response.json().await.map_err(TestError::Parsing)?;
                Err(TestError::RateLimit(error_body))
            }
            _ => {
                let error_body: ErrorResponse = response
                    .json()
                    .await
                    .unwrap_or_else(|_| ErrorResponse {
                        error: "UnknownError".to_string(),
                        message: format!("HTTP {}", status),
                        details: None,
                    });
                Err(TestError::Api(status, error_body))
            }
        }
    }

    /// Get statistics for a short code
    pub async fn get_stats(&mut self, short_code: &str) -> Result<StatsResponse, TestError> {
        let start = Instant::now();
        let url = format!("{}/stats/{}", self.config.base_url, short_code);

        let response = self
            .client
            .get(&url)
            .send()
            .await
            .map_err(TestError::Http)?;

        let status = response.status().as_u16();
        self.record_request("GET", &format!("/stats/{}", short_code), status, start.elapsed());

        match status {
            200 => {
                let response_body: StatsResponse =
                    response.json().await.map_err(TestError::Parsing)?;
                Ok(response_body)
            }
            404 => Err(TestError::NotFound),
            429 => {
                let error_body: ErrorResponse =
                    response.json().await.map_err(TestError::Parsing)?;
                Err(TestError::RateLimit(error_body))
            }
            _ => {
                let error_body: ErrorResponse = response
                    .json()
                    .await
                    .unwrap_or_else(|_| ErrorResponse {
                        error: "UnknownError".to_string(),
                        message: format!("HTTP {}", status),
                        details: None,
                    });
                Err(TestError::Api(status, error_body))
            }
        }
    }

    /// Make a raw HTTP request for testing edge cases
    pub async fn raw_request(
        &mut self,
        method: &str,
        path: &str,
        body: Option<serde_json::Value>,
        headers: Option<HashMap<String, String>>,
    ) -> Result<(u16, serde_json::Value), TestError> {
        let start = Instant::now();
        let url = format!("{}{}", self.config.base_url, path);

        let mut request_builder = match method.to_uppercase().as_str() {
            "GET" => self.client.get(&url),
            "POST" => self.client.post(&url),
            "PUT" => self.client.put(&url),
            "DELETE" => self.client.delete(&url),
            _ => return Err(TestError::UnsupportedMethod(method.to_string())),
        };

        if let Some(body) = body {
            request_builder = request_builder.json(&body);
        }

        if let Some(headers) = headers {
            for (key, value) in headers {
                request_builder = request_builder.header(&key, &value);
            }
        }

        let response = request_builder.send().await.map_err(TestError::Http)?;

        let status = response.status().as_u16();
        self.record_request(method, path, status, start.elapsed());

        let response_body: serde_json::Value = response
            .json()
            .await
            .unwrap_or_else(|_| serde_json::json!({}));

        Ok((status, response_body))
    }

    /// Check if response includes cache headers
    pub async fn check_cache_headers(&mut self, short_code: &str) -> Result<CacheInfo, TestError> {
        let start = Instant::now();
        let url = format!("{}/{}", self.config.cloudfront_url, short_code);

        let response = self
            .client
            .get(&url)
            .send()
            .await
            .map_err(TestError::Http)?;

        let status = response.status().as_u16();
        self.record_request("GET", &format!("/{}", short_code), status, start.elapsed());

        let headers = response.headers();
        Ok(CacheInfo {
            cache_control: headers
                .get("cache-control")
                .and_then(|v| v.to_str().ok())
                .map(|s| s.to_string()),
            cloudfront_cache_status: headers
                .get("x-cache")
                .and_then(|v| v.to_str().ok())
                .map(|s| s.to_string()),
            age: headers
                .get("age")
                .and_then(|v| v.to_str().ok())
                .and_then(|s| s.parse().ok()),
            expires: headers
                .get("expires")
                .and_then(|v| v.to_str().ok())
                .map(|s| s.to_string()),
        })
    }

    fn record_request(&mut self, method: &str, path: &str, status: u16, duration: Duration) {
        self.request_history.push(RequestRecord {
            timestamp: Instant::now(),
            method: method.to_string(),
            path: path.to_string(),
            status,
            response_time_ms: duration.as_millis() as u64,
            ip_address: None, // Could be enhanced to track if needed
        });
    }

    pub fn get_request_history(&self) -> &[RequestRecord] {
        &self.request_history
    }

    pub fn clear_history(&mut self) {
        self.request_history.clear();
    }
}

#[derive(Debug)]
pub struct CacheInfo {
    pub cache_control: Option<String>,
    pub cloudfront_cache_status: Option<String>,
    pub age: Option<u64>,
    pub expires: Option<String>,
}

/// Test error types
#[derive(Debug)]
pub enum TestError {
    Http(reqwest::Error),
    Parsing(reqwest::Error),
    Api(u16, ErrorResponse),
    RateLimit(ErrorResponse),
    NotFound,
    MissingRedirectLocation,
    UnsupportedMethod(String),
    Timeout,
    ValidationError(String),
}

impl std::fmt::Display for TestError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TestError::Http(e) => write!(f, "HTTP error: {}", e),
            TestError::Parsing(e) => write!(f, "JSON parsing error: {}", e),
            TestError::Api(status, err) => write!(f, "API error {}: {}", status, err.message),
            TestError::RateLimit(err) => write!(f, "Rate limit exceeded: {}", err.message),
            TestError::NotFound => write!(f, "Resource not found"),
            TestError::MissingRedirectLocation => write!(f, "Redirect response missing Location header"),
            TestError::UnsupportedMethod(method) => write!(f, "Unsupported HTTP method: {}", method),
            TestError::Timeout => write!(f, "Request timeout"),
            TestError::ValidationError(msg) => write!(f, "Validation error: {}", msg),
        }
    }
}

impl std::error::Error for TestError {}

/// Utility functions for tests
pub mod utils {
    use super::*;
    use rand::distributions::Alphanumeric;
    use rand::{thread_rng, Rng};

    /// Generate a random test URL
    pub fn random_test_url() -> String {
        let random_path: String = thread_rng()
            .sample_iter(&Alphanumeric)
            .take(10)
            .map(char::from)
            .collect();
        format!("https://example.com/test-{}", random_path)
    }

    /// Generate a random custom code
    pub fn random_custom_code() -> String {
        thread_rng()
            .sample_iter(&Alphanumeric)
            .take(8)
            .map(char::from)
            .collect()
    }

    /// Validate URL format
    pub fn is_valid_url(url: &str) -> bool {
        Url::parse(url).is_ok()
    }

    /// Calculate requests per second from request history
    pub fn calculate_rps(requests: &[RequestRecord], window_seconds: u64) -> f64 {
        if requests.is_empty() {
            return 0.0;
        }

        let now = Instant::now();
        let window_start = now - Duration::from_secs(window_seconds);

        let recent_requests: Vec<_> = requests
            .iter()
            .filter(|r| r.timestamp >= window_start)
            .collect();

        recent_requests.len() as f64 / window_seconds as f64
    }

    /// Calculate response time percentiles
    pub fn calculate_percentiles(requests: &[RequestRecord]) -> (u64, u64, u64) {
        if requests.is_empty() {
            return (0, 0, 0);
        }

        let mut response_times: Vec<u64> = requests.iter().map(|r| r.response_time_ms).collect();
        response_times.sort();

        let len = response_times.len();
        let p50 = response_times[len * 50 / 100];
        let p95 = response_times[len * 95 / 100];
        let p99 = response_times[len * 99 / 100];

        (p50, p95, p99)
    }

    /// Wait for a specified duration with logging
    pub async fn wait_with_logging(duration: Duration, reason: &str) {
        tracing::info!("Waiting {} seconds for {}", duration.as_secs(), reason);
        sleep(duration).await;
    }
}

/// Rate limiting utilities
pub mod rate_limiting {
    use super::*;

    /// Test rate limits by making requests at a specified rate
    pub async fn test_rate_limit(
        client: &mut TestClient,
        request_rate: u32,
        duration_seconds: u64,
    ) -> RateLimitTestResult {
        let mut successful_requests = 0;
        let mut rate_limited_requests = 0;
        let mut error_requests = 0;

        let start_time = Instant::now();
        let interval = Duration::from_millis(1000 / request_rate as u64);

        while start_time.elapsed().as_secs() < duration_seconds {
            let request = CreateUrlRequest {
                url: utils::random_test_url(),
                custom_code: None,
            };

            match client.create_url(request).await {
                Ok(_) => successful_requests += 1,
                Err(TestError::RateLimit(_)) => rate_limited_requests += 1,
                Err(_) => error_requests += 1,
            }

            sleep(interval).await;
        }

        RateLimitTestResult {
            successful_requests,
            rate_limited_requests,
            error_requests,
            duration_seconds,
            target_rate: request_rate,
        }
    }

    /// Burst test - send many requests quickly
    pub async fn burst_test(
        client: &mut TestClient,
        burst_size: u32,
    ) -> RateLimitTestResult {
        let mut successful_requests = 0;
        let mut rate_limited_requests = 0;
        let mut error_requests = 0;

        let start_time = Instant::now();

        // Send all requests as quickly as possible
        for _ in 0..burst_size {
            let request = CreateUrlRequest {
                url: utils::random_test_url(),
                custom_code: None,
            };

            match client.create_url(request).await {
                Ok(_) => successful_requests += 1,
                Err(TestError::RateLimit(_)) => rate_limited_requests += 1,
                Err(_) => error_requests += 1,
            }
        }

        let duration = start_time.elapsed();

        RateLimitTestResult {
            successful_requests,
            rate_limited_requests,
            error_requests,
            duration_seconds: duration.as_secs(),
            target_rate: (burst_size as f64 / duration.as_secs_f64()) as u32,
        }
    }

    #[derive(Debug)]
    pub struct RateLimitTestResult {
        pub successful_requests: u32,
        pub rate_limited_requests: u32,
        pub error_requests: u32,
        pub duration_seconds: u64,
        pub target_rate: u32,
    }

    impl RateLimitTestResult {
        pub fn actual_rate(&self) -> f64 {
            self.successful_requests as f64 / self.duration_seconds.max(1) as f64
        }

        pub fn total_requests(&self) -> u32 {
            self.successful_requests + self.rate_limited_requests + self.error_requests
        }

        pub fn rate_limit_percentage(&self) -> f64 {
            if self.total_requests() == 0 {
                0.0
            } else {
                (self.rate_limited_requests as f64 / self.total_requests() as f64) * 100.0
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_from_env() {
        std::env::set_var("API_BASE_URL", "https://test.example.com");
        std::env::set_var("TEST_ENV", "test");

        let config = TestConfig::default();
        assert_eq!(config.base_url, "https://test.example.com");
        assert_eq!(config.environment, "test");
    }

    #[test]
    fn test_url_validation() {
        assert!(utils::is_valid_url("https://example.com"));
        assert!(utils::is_valid_url("http://test.com/path"));
        assert!(!utils::is_valid_url("not-a-url"));
        assert!(!utils::is_valid_url(""));
    }

    #[test]
    fn test_random_generators() {
        let url1 = utils::random_test_url();
        let url2 = utils::random_test_url();
        assert_ne!(url1, url2);
        assert!(utils::is_valid_url(&url1));
        assert!(utils::is_valid_url(&url2));

        let code1 = utils::random_custom_code();
        let code2 = utils::random_custom_code();
        assert_ne!(code1, code2);
        assert_eq!(code1.len(), 8);
        assert_eq!(code2.len(), 8);
    }
}