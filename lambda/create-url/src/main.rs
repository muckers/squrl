use aws_config::BehaviorVersion;
use aws_sdk_dynamodb::Client as DynamoDbClient;
use chrono::{DateTime, Utc};
use lambda_runtime::{run, service_fn, Error, LambdaEvent};
//use lambda_web::{is_running_on_lambda, launch, IntoResponse, RequestExt};
use nanoid::nanoid;
use serde_json::Value;
use std::env;
use tracing::{error, instrument};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use validator::Validate;

// use squrl_shared::base62::encode_base62;
use squrl_shared::dynamodb::DynamoDbClient as UrlDynamoDbClient;
use squrl_shared::error::UrlShortenerError;
use squrl_shared::models::{CreateUrlRequest, CreateUrlResponse, ErrorResponse, UrlItem};
use squrl_shared::validation::{validate_custom_code, validate_url};

fn init_tracing() {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(
            std::env::var("RUST_LOG").unwrap_or_else(|_| "info".into())
        ))
        .with(tracing_subscriber::fmt::layer().json())
        .init();
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    init_tracing();
    
    let config = aws_config::load_defaults(BehaviorVersion::latest()).await;
    
    let dynamodb_client = if let Ok(endpoint_url) = env::var("AWS_ENDPOINT_URL") {
        // Local development with LocalStack
        let dynamodb_config = aws_sdk_dynamodb::config::Builder::from(&config)
            .endpoint_url(endpoint_url)
            .build();
        DynamoDbClient::from_conf(dynamodb_config)
    } else {
        DynamoDbClient::new(&config)
    };
    
    let table_name = env::var("DYNAMODB_TABLE_NAME")
        .unwrap_or_else(|_| "squrl-urls".to_string());
    
    let db_client = UrlDynamoDbClient::new(dynamodb_client, table_name);
    
    run(service_fn(move |event| function_handler(event, db_client.clone()))).await
}

#[instrument(skip(db_client))]
async fn function_handler(
    event: LambdaEvent<Value>,
    db_client: UrlDynamoDbClient,
) -> Result<Value, Error> {
    match handler_impl(event.payload, &db_client).await {
        Ok(response) => Ok(response),
        Err(err) => {
            error!("Function error: {}", err);
            Ok(create_error_response(&err))
        }
    }
}

async fn handler_impl(
    payload: Value,
    db_client: &UrlDynamoDbClient,
) -> Result<Value, UrlShortenerError> {
    let request: CreateUrlRequest = serde_json::from_value(payload)
        .map_err(|e| UrlShortenerError::ValidationError(e.to_string()))?;
    
    request.validate()
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
    let expires_at = request.ttl_hours.map(|hours| {
        (now + chrono::Duration::hours(hours as i64)).timestamp()
    });

    let url_item = UrlItem {
        short_code: short_code.clone(),
        original_url: request.original_url.clone(),
        created_at: now.to_rfc3339(),
        expires_at,
        click_count: 0,
        creator_ip: None, // TODO: Extract from Lambda context
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
    let short_url = format!("https://sqrl.co/{}", url_item.short_code);
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

fn create_error_response(err: &UrlShortenerError) -> Value {
    let error_response = ErrorResponse {
        error: err.error_type().to_string(),
        message: err.to_string(),
        details: None,
    };

    serde_json::to_value(error_response).unwrap()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_short_code() {
        let code = generate_short_code();
        assert_eq!(code.len(), 8);
        assert!(code.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-'));
    }
}

// Handler removed - using only Lambda runtime handler