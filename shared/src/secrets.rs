use aws_sdk_secretsmanager::Client as SecretsManagerClient;
use serde_json::Value;
use std::collections::HashMap;
use std::env;
use tracing::{debug, error, info, warn};

use crate::error::UrlShortenerError;

/// Configuration struct for Secrets Manager
#[derive(Debug, Clone)]
pub struct SecretsManagerConfig {
    client: SecretsManagerClient,
    secret_cache: std::sync::Arc<std::sync::RwLock<HashMap<String, CachedSecret>>>,
    cache_ttl_seconds: u64,
}

/// Cached secret with expiration time
#[derive(Debug, Clone)]
struct CachedSecret {
    value: String,
    expires_at: std::time::SystemTime,
}

/// Application configuration that can be loaded from Secrets Manager or environment variables
#[derive(Debug, Clone)]
pub struct AppConfig {
    pub dynamodb_table_name: String,
    pub short_url_base: String,
    pub rust_log_level: String,
    // Add other sensitive configuration here as needed
    pub api_keys: HashMap<String, String>,
}

impl SecretsManagerConfig {
    /// Create a new SecretsManagerConfig with the provided client
    pub fn new(client: SecretsManagerClient) -> Self {
        Self {
            client,
            secret_cache: std::sync::Arc::new(std::sync::RwLock::new(HashMap::new())),
            cache_ttl_seconds: 300, // 5 minutes default cache TTL
        }
    }

    /// Create a new SecretsManagerConfig with custom cache TTL
    pub fn with_cache_ttl(client: SecretsManagerClient, cache_ttl_seconds: u64) -> Self {
        Self {
            client,
            secret_cache: std::sync::Arc::new(std::sync::RwLock::new(HashMap::new())),
            cache_ttl_seconds,
        }
    }

    /// Get a secret value by name, with caching to avoid repeated API calls
    pub async fn get_secret(&self, secret_name: &str) -> Result<String, UrlShortenerError> {
        debug!("Getting secret: {}", secret_name);

        // Check cache first
        if let Some(cached_value) = self.get_cached_secret(secret_name) {
            debug!("Using cached secret: {}", secret_name);
            return Ok(cached_value);
        }

        // Fetch from Secrets Manager
        info!("Fetching secret from AWS Secrets Manager: {}", secret_name);
        
        let result = self
            .client
            .get_secret_value()
            .secret_id(secret_name)
            .send()
            .await
            .map_err(|e| {
                error!("Failed to retrieve secret {}: {}", secret_name, e);
                UrlShortenerError::InternalError(e.into())
            })?;

        let secret_string = result
            .secret_string()
            .ok_or_else(|| {
                error!("Secret {} exists but has no string value", secret_name);
                UrlShortenerError::ConfigurationError(format!(
                    "Secret {} exists but has no string value",
                    secret_name
                ))
            })?
            .to_string();

        // Cache the secret
        self.cache_secret(secret_name.to_string(), secret_string.clone());

        info!("Successfully retrieved secret: {}", secret_name);
        Ok(secret_string)
    }

    /// Get a JSON secret and parse it as a specific type
    pub async fn get_json_secret<T>(&self, secret_name: &str) -> Result<T, UrlShortenerError>
    where
        T: serde::de::DeserializeOwned,
    {
        let secret_value = self.get_secret(secret_name).await?;
        
        serde_json::from_str(&secret_value)
            .map_err(|e| {
                error!("Failed to parse JSON secret {}: {}", secret_name, e);
                UrlShortenerError::ConfigurationError(format!(
                    "Failed to parse JSON secret {}: {}",
                    secret_name, e
                ))
            })
    }

    /// Get multiple secrets at once (useful for batch loading configuration)
    pub async fn get_secrets(
        &self,
        secret_names: &[&str],
    ) -> Result<HashMap<String, String>, UrlShortenerError> {
        let mut results = HashMap::new();
        
        for &secret_name in secret_names {
            match self.get_secret(secret_name).await {
                Ok(value) => {
                    results.insert(secret_name.to_string(), value);
                }
                Err(e) => {
                    warn!("Failed to retrieve secret {}: {}", secret_name, e);
                    // Continue with other secrets rather than failing completely
                }
            }
        }
        
        Ok(results)
    }

    /// Check cache for a secret
    fn get_cached_secret(&self, secret_name: &str) -> Option<String> {
        let cache = self.secret_cache.read().ok()?;
        let cached = cache.get(secret_name)?;
        
        // Check if cache entry is still valid
        if cached.expires_at > std::time::SystemTime::now() {
            Some(cached.value.clone())
        } else {
            // Cache expired
            None
        }
    }

    /// Cache a secret with TTL
    fn cache_secret(&self, secret_name: String, value: String) {
        if let Ok(mut cache) = self.secret_cache.write() {
            let expires_at = std::time::SystemTime::now()
                + std::time::Duration::from_secs(self.cache_ttl_seconds);
            
            cache.insert(
                secret_name,
                CachedSecret { value, expires_at },
            );
        }
    }

    /// Clear the secret cache (useful for testing or forced refresh)
    pub fn clear_cache(&self) {
        if let Ok(mut cache) = self.secret_cache.write() {
            cache.clear();
        }
    }
}

impl AppConfig {
    /// Load configuration from Secrets Manager with fallback to environment variables
    pub async fn load_from_secrets_manager(
        secrets_client: &SecretsManagerConfig,
        environment: &str,
    ) -> Result<Self, UrlShortenerError> {
        info!("Loading application configuration for environment: {}", environment);
        
        let secret_name = format!("{}-squrl-config", environment);
        
        // Try to load from Secrets Manager first
        match secrets_client.get_json_secret::<Value>(&secret_name).await {
            Ok(config_json) => {
                info!("Loaded configuration from Secrets Manager");
                Self::from_json_config(&config_json)
            }
            Err(e) => {
                warn!("Failed to load from Secrets Manager, falling back to environment variables: {}", e);
                Self::from_env_vars()
            }
        }
    }

    /// Load configuration from environment variables (backward compatibility)
    pub fn from_env_vars() -> Result<Self, UrlShortenerError> {
        info!("Loading configuration from environment variables");
        
        let dynamodb_table_name = env::var("DYNAMODB_TABLE_NAME")
            .unwrap_or_else(|_| "squrl-urls".to_string());
            
        let short_url_base = env::var("SHORT_URL_BASE")
            .unwrap_or_else(|_| "https://sqrl.co".to_string());
            
        let rust_log_level = env::var("RUST_LOG")
            .unwrap_or_else(|_| "info".to_string());

        // Load any API keys from environment (format: API_KEY_<NAME>=<value>)
        let mut api_keys = HashMap::new();
        for (key, value) in env::vars() {
            if key.starts_with("API_KEY_") {
                let key_name = key.strip_prefix("API_KEY_").unwrap().to_lowercase();
                api_keys.insert(key_name, value);
            }
        }

        Ok(Self {
            dynamodb_table_name,
            short_url_base,
            rust_log_level,
            api_keys,
        })
    }

    /// Parse configuration from JSON value (from Secrets Manager)
    fn from_json_config(config_json: &Value) -> Result<Self, UrlShortenerError> {
        let dynamodb_table_name = config_json
            .get("dynamodb_table_name")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
            .unwrap_or_else(|| "squrl-urls".to_string());

        let short_url_base = config_json
            .get("short_url_base")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
            .unwrap_or_else(|| "https://sqrl.co".to_string());

        let rust_log_level = config_json
            .get("rust_log_level")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
            .unwrap_or_else(|| "info".to_string());

        // Parse API keys from JSON
        let mut api_keys = HashMap::new();
        if let Some(keys_obj) = config_json.get("api_keys").and_then(|v| v.as_object()) {
            for (key, value) in keys_obj {
                if let Some(value_str) = value.as_str() {
                    api_keys.insert(key.clone(), value_str.to_string());
                }
            }
        }

        Ok(Self {
            dynamodb_table_name,
            short_url_base,
            rust_log_level,
            api_keys,
        })
    }

    /// Load configuration with automatic environment detection
    pub async fn load_auto(
        secrets_client: Option<&SecretsManagerConfig>,
    ) -> Result<Self, UrlShortenerError> {
        // Try to detect environment from common environment variables
        let environment = env::var("ENVIRONMENT")
            .or_else(|_| env::var("ENV"))
            .or_else(|_| env::var("STAGE"))
            .unwrap_or_else(|_| "dev".to_string());

        match secrets_client {
            Some(client) => Self::load_from_secrets_manager(client, &environment).await,
            None => {
                info!("No Secrets Manager client provided, using environment variables");
                Self::from_env_vars()
            }
        }
    }

    /// Get API key by name
    pub fn get_api_key(&self, key_name: &str) -> Option<&str> {
        self.api_keys.get(key_name).map(|s| s.as_str())
    }

    /// Check if we have any API keys configured
    pub fn has_api_keys(&self) -> bool {
        !self.api_keys.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    
    #[test]
    fn test_app_config_from_json() {
        let config_json = json!({
            "dynamodb_table_name": "json-table",
            "short_url_base": "https://json.co",
            "rust_log_level": "trace",
            "api_keys": {
                "service1": "key-123",
                "service2": "key-456"
            }
        });

        let config = AppConfig::from_json_config(&config_json).unwrap();
        
        assert_eq!(config.dynamodb_table_name, "json-table");
        assert_eq!(config.short_url_base, "https://json.co");
        assert_eq!(config.rust_log_level, "trace");
        assert_eq!(config.get_api_key("service1"), Some("key-123"));
        assert_eq!(config.get_api_key("service2"), Some("key-456"));
        assert!(config.has_api_keys());
    }

    #[test]
    fn test_app_config_json_defaults() {
        let config_json = json!({});
        let config = AppConfig::from_json_config(&config_json).unwrap();
        
        assert_eq!(config.dynamodb_table_name, "squrl-urls");
        assert_eq!(config.short_url_base, "https://sqrl.co");
        assert_eq!(config.rust_log_level, "info");
        assert!(!config.has_api_keys());
    }

    #[test]
    fn test_secrets_manager_config_cache() {
        // Test that we can create a secrets manager config
        // Note: We can't test the actual AWS functionality without mocking
        use aws_config::BehaviorVersion;
        use aws_sdk_secretsmanager::Client;
        
        // Create a minimal config for testing
        let client_config = aws_sdk_secretsmanager::config::Config::builder()
            .behavior_version(BehaviorVersion::latest())
            .endpoint_url("http://localhost:4566") // LocalStack endpoint for testing
            .build();
        let client = Client::from_conf(client_config);
        
        let config = SecretsManagerConfig::new(client);
        config.clear_cache(); // Test cache clearing
        
        // Just test that the config was created successfully
        // Real functionality would require LocalStack or AWS credentials
    }
}