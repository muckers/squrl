use serde::{Deserialize, Serialize};
use std::collections::HashMap;
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

// API Gateway event structures
#[derive(Debug, Deserialize)]
pub struct ApiGatewayProxyEvent {
    pub body: Option<String>,
    #[serde(rename = "pathParameters")]
    pub path_parameters: Option<HashMap<String, String>>,
    #[serde(rename = "queryStringParameters")]
    pub query_string_parameters: Option<HashMap<String, String>>,
    #[serde(rename = "httpMethod")]
    pub http_method: String,
    pub headers: Option<HashMap<String, String>>,
    #[serde(rename = "requestContext")]
    pub request_context: Option<RequestContext>,
}

#[derive(Debug, Deserialize)]
pub struct RequestContext {
    pub identity: Option<Identity>,
}

#[derive(Debug, Deserialize)]
pub struct Identity {
    #[serde(rename = "sourceIp")]
    pub source_ip: Option<String>,
    #[serde(rename = "userAgent")]
    pub user_agent: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ApiGatewayProxyResponse {
    #[serde(rename = "statusCode")]
    pub status_code: u16,
    pub headers: Option<HashMap<String, String>>,
    pub body: String,
    #[serde(rename = "isBase64Encoded")]
    pub is_base64_encoded: bool,
}

impl ApiGatewayProxyResponse {
    pub fn new(status_code: u16, body: String) -> Self {
        let mut headers = HashMap::new();
        headers.insert("Content-Type".to_string(), "application/json".to_string());
        headers.insert("Access-Control-Allow-Origin".to_string(), "*".to_string());
        headers.insert("Access-Control-Allow-Headers".to_string(), "Content-Type".to_string());
        headers.insert("Access-Control-Allow-Methods".to_string(), "GET, POST, OPTIONS".to_string());

        Self {
            status_code,
            headers: Some(headers),
            body,
            is_base64_encoded: false,
        }
    }

    pub fn redirect(location: String) -> Self {
        let mut headers = HashMap::new();
        headers.insert("Location".to_string(), location);
        headers.insert("Access-Control-Allow-Origin".to_string(), "*".to_string());

        Self {
            status_code: 301,
            headers: Some(headers),
            body: "".to_string(),
            is_base64_encoded: false,
        }
    }
}

// Helper function to detect if event is from API Gateway
pub fn is_api_gateway_event(payload: &serde_json::Value) -> bool {
    payload.get("httpMethod").is_some() || payload.get("requestContext").is_some()
}