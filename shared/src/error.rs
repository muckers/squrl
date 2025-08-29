use thiserror::Error;

#[derive(Debug, Error)]
pub enum UrlShortenerError {
    #[error("Invalid URL: {0}")]
    InvalidUrl(String),
    
    #[error("Short code already exists: {0}")]
    ShortCodeExists(String),
    
    #[error("Short code not found: {0}")]
    ShortCodeNotFound(String),
    
    #[error("URL has expired")]
    UrlExpired,
    
    #[error("Database error: {0}")]
    DatabaseError(String),
    
    #[error("Validation error: {0}")]
    ValidationError(String),
    
    #[error("Configuration error: {0}")]
    ConfigurationError(String),
    
    #[error("Rate limit exceeded")]
    RateLimitExceeded,
    
    #[error("Serialization error: {0}")]
    SerializationError(#[from] serde_json::Error),
    
    #[error("Internal server error: {0}")]
    InternalError(#[from] anyhow::Error),
}

impl UrlShortenerError {
    pub fn status_code(&self) -> u16 {
        match self {
            UrlShortenerError::InvalidUrl(_) => 400,
            UrlShortenerError::ShortCodeExists(_) => 409,
            UrlShortenerError::ShortCodeNotFound(_) => 404,
            UrlShortenerError::UrlExpired => 410,
            UrlShortenerError::ValidationError(_) => 400,
            UrlShortenerError::ConfigurationError(_) => 500,
            UrlShortenerError::RateLimitExceeded => 429,
            UrlShortenerError::SerializationError(_) => 500,
            _ => 500,
        }
    }

    pub fn error_type(&self) -> &'static str {
        match self {
            UrlShortenerError::InvalidUrl(_) => "InvalidUrl",
            UrlShortenerError::ShortCodeExists(_) => "ConflictError",
            UrlShortenerError::ShortCodeNotFound(_) => "NotFound",
            UrlShortenerError::UrlExpired => "Gone",
            UrlShortenerError::ValidationError(_) => "ValidationError",
            UrlShortenerError::ConfigurationError(_) => "ConfigurationError",
            UrlShortenerError::RateLimitExceeded => "RateLimitExceeded",
            UrlShortenerError::SerializationError(_) => "SerializationError",
            _ => "InternalServerError",
        }
    }
}