use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Deserialize, Validate)]
pub struct CreateUrlRequest {
    #[validate(url)]
    pub original_url: String,
    
    #[validate(length(min = 3, max = 20))]
    pub custom_code: Option<String>,
    
    #[validate(range(min = 1, max = 87600))]
    pub ttl_hours: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct CreateUrlResponse {
    pub short_code: String,
    pub original_url: String,
    pub short_url: String,
    pub created_at: String,
    pub expires_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct RedirectRequest {
    pub short_code: String,
    pub client_ip: Option<String>,
    pub user_agent: Option<String>,
    pub referer: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct RedirectResponse {
    pub original_url: String,
    pub redirect_type: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct AnalyticsEvent {
    pub short_code: String,
    pub timestamp: String,
    pub client_ip: Option<String>,
    pub user_agent: Option<String>,
    pub referer: Option<String>,
    pub country: Option<String>,
    pub city: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ErrorResponse {
    pub error: String,
    pub message: String,
    pub details: Option<serde_json::Value>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UrlItem {
    pub short_code: String,
    pub original_url: String,
    pub created_at: String,
    pub expires_at: Option<i64>,
    pub click_count: u64,
    pub creator_ip: Option<String>,
    pub custom_code: bool,
    pub status: String,
}