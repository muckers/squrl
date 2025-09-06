use aws_config::BehaviorVersion;
use aws_sdk_dynamodb::Client as DynamoDbClient;
use chrono::{DateTime, Utc};
use lambda_runtime::{Error, LambdaEvent, run, service_fn};
use nanoid::nanoid;
use serde_json::Value;
use std::env;
use tracing::{error, instrument};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use validator::Validate;

use squrl_shared::dynamodb::DynamoDbClient as UrlDynamoDbClient;
use squrl_shared::error::UrlShortenerError;
use squrl_shared::models::{
    ApiGatewayProxyEvent, ApiGatewayProxyResponse, CreateUrlRequest, CreateUrlResponse,
    ErrorResponse, UrlItem, is_api_gateway_event,
};
use squrl_shared::validation::{validate_custom_code, validate_url};

fn init_tracing() {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(
            std::env::var("RUST_LOG").unwrap_or_else(|_| "debug".into()),
        ))
        .with(tracing_subscriber::fmt::layer().json())
        .init();
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    init_tracing();

    tracing::info!("Starting create-url Lambda function");
    tracing::info!("Environment variables:");
    for (key, value) in env::vars() {
        if key.contains("AWS")
            || key.contains("DYNAMODB")
            || key.contains("RUST")
            || key.contains("CARGO")
        {
            tracing::info!("{}: {}", key, value);
        }
    }

    let config = aws_config::load_defaults(BehaviorVersion::latest()).await;

    let dynamodb_client = if let Ok(endpoint_url) = env::var("AWS_ENDPOINT_URL") {
        tracing::info!("Using LocalStack endpoint: {}", endpoint_url);
        // Local development with LocalStack
        let dynamodb_config = aws_sdk_dynamodb::config::Builder::from(&config)
            .endpoint_url(endpoint_url)
            .build();
        DynamoDbClient::from_conf(dynamodb_config)
    } else {
        tracing::info!("Using AWS DynamoDB");
        DynamoDbClient::new(&config)
    };

    let table_name = env::var("DYNAMODB_TABLE_NAME").unwrap_or_else(|_| "squrl-urls".to_string());
    tracing::info!("Using DynamoDB table: {}", table_name);

    let db_client = UrlDynamoDbClient::new(dynamodb_client, table_name);

    run(service_fn(move |event| {
        function_handler(event, db_client.clone())
    }))
    .await
}

#[instrument(skip(db_client))]
async fn function_handler(
    event: LambdaEvent<Value>,
    db_client: UrlDynamoDbClient,
) -> Result<Value, Error> {
    tracing::info!(
        "Received event: {}",
        serde_json::to_string_pretty(&event.payload)
            .unwrap_or_else(|_| "Unable to serialize".to_string())
    );

    let is_api_gateway = is_api_gateway_event(&event.payload);
    let is_local_http = env::var("CARGO_LAMBDA_INVOKE_PORT").is_ok();

    tracing::info!(
        "is_api_gateway: {}, is_local_http: {}",
        is_api_gateway,
        is_local_http
    );

    match handler_impl(event.payload, &db_client).await {
        Ok(response) => {
            tracing::info!("Handler succeeded, creating response");
            // Always return API Gateway format for local HTTP server or actual API Gateway
            if is_api_gateway || is_local_http {
                let result = create_api_gateway_success_response(response);
                tracing::info!("API Gateway response created");
                Ok(result)
            } else {
                tracing::info!("Direct response created");
                Ok(response)
            }
        }
        Err(err) => {
            error!("Function error: {}", err);
            let result = create_error_response(&err, is_api_gateway || is_local_http);
            error!("Error response created");
            Ok(result)
        }
    }
}

async fn handler_impl(
    payload: Value,
    db_client: &UrlDynamoDbClient,
) -> Result<Value, UrlShortenerError> {
    let request: CreateUrlRequest = if is_api_gateway_event(&payload) {
        // Parse API Gateway event
        let api_event: ApiGatewayProxyEvent = serde_json::from_value(payload).map_err(|e| {
            UrlShortenerError::ValidationError(format!("Invalid API Gateway event: {}", e))
        })?;

        // Extract body and parse as JSON
        let body = api_event.body.ok_or_else(|| {
            UrlShortenerError::ValidationError("Missing request body".to_string())
        })?;

        serde_json::from_str(&body).map_err(|e| {
            UrlShortenerError::ValidationError(format!("Invalid JSON in body: {}", e))
        })?
    } else {
        // Direct Lambda invocation
        serde_json::from_value(payload)
            .map_err(|e| UrlShortenerError::ValidationError(e.to_string()))?
    };

    request
        .validate()
        .map_err(|e| UrlShortenerError::ValidationError(e.to_string()))?;

    let _validated_url = validate_url(&request.original_url)?;

    if let Some(custom_code) = &request.custom_code {
        validate_custom_code(custom_code)?;
    }

    // Check for existing URL
    if let Some(existing_item) = db_client.find_existing_url(&request.original_url).await? {
        return Ok(create_success_response(existing_item));
    }

    // Generate short code
    let short_code = if let Some(ref custom_code) = request.custom_code {
        custom_code.clone()
    } else {
        generate_short_code()
    };

    // Calculate expiration
    let now = Utc::now();
    let expires_at = request
        .ttl_hours
        .map(|hours| (now + chrono::Duration::hours(hours as i64)).timestamp());

    let url_item = UrlItem {
        short_code: short_code.clone(),
        original_url: request.original_url.clone(),
        created_at: now.to_rfc3339(),
        expires_at,
        click_count: 0,
        custom_code: request.custom_code.is_some(),
        status: "active".to_string(),
    };

    // Store in DynamoDB
    db_client.put_url(&url_item).await?;

    Ok(create_success_response(url_item))
}

fn generate_short_code() -> String {
    // Use nanoid for collision-resistant ID generation
    let id = nanoid!(8, &nanoid::alphabet::SAFE);
    id
}

fn create_success_response(url_item: UrlItem) -> Value {
    let base_url = env::var("SHORT_URL_BASE").unwrap_or_else(|_| "https://sqrl.co".to_string());
    let short_url = format!("{}/{}", base_url, url_item.short_code);
    let expires_at = url_item.expires_at.map(|ts| {
        DateTime::from_timestamp(ts, 0)
            .unwrap_or_else(Utc::now)
            .to_rfc3339()
    });

    let response = CreateUrlResponse {
        short_code: url_item.short_code,
        original_url: url_item.original_url,
        short_url,
        created_at: url_item.created_at,
        expires_at,
    };

    serde_json::to_value(response).unwrap()
}

fn create_api_gateway_success_response(response_data: Value) -> Value {
    let api_response =
        ApiGatewayProxyResponse::new(200, serde_json::to_string(&response_data).unwrap());

    serde_json::to_value(api_response).unwrap()
}

fn create_error_response(err: &UrlShortenerError, is_api_gateway: bool) -> Value {
    let error_response = ErrorResponse {
        error: err.error_type().to_string(),
        message: err.to_string(),
        details: None,
    };

    if is_api_gateway {
        let api_response = ApiGatewayProxyResponse::new(
            err.status_code(),
            serde_json::to_string(&error_response).unwrap(),
        );
        serde_json::to_value(api_response).unwrap()
    } else {
        serde_json::to_value(error_response).unwrap()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_generate_short_code() {
        let code = generate_short_code();
        assert_eq!(code.len(), 8);
        assert!(
            code.chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
        );
    }

    #[test]
    fn test_api_gateway_event_detection() {
        // Test API Gateway event
        let api_gateway_event = json!({
            "httpMethod": "POST",
            "body": "{\"original_url\": \"https://example.com\"}",
            "headers": {"Content-Type": "application/json"},
            "requestContext": {
                "identity": {"sourceIp": "192.168.1.1"}
            }
        });

        assert!(is_api_gateway_event(&api_gateway_event));

        // Test direct invocation
        let direct_event = json!({
            "original_url": "https://example.com"
        });

        assert!(!is_api_gateway_event(&direct_event));
    }

    #[test]
    fn test_api_gateway_response_format() {
        let response_data = json!({
            "short_code": "abc123",
            "original_url": "https://example.com",
            "short_url": "https://sqrl.co/abc123",
            "created_at": "2025-08-24T10:30:00Z"
        });

        let api_response = create_api_gateway_success_response(response_data);

        assert_eq!(api_response["statusCode"], 200);
        assert!(api_response["headers"].is_object());
        assert!(api_response["body"].is_string());
        assert_eq!(api_response["isBase64Encoded"], false);
    }
}

// Handler removed - using only Lambda runtime handler
