use aws_config::BehaviorVersion;
use aws_sdk_dynamodb::Client as DynamoDbClient;
use aws_sdk_kinesis::Client as KinesisClient;
use chrono::Utc;
use lambda_runtime::{run, service_fn, Error, LambdaEvent};
//use lambda_web::{is_running_on_lambda, launch, IntoResponse, RequestExt};
use serde_json::{json, Value};
use std::env;
use tracing::{error, info, instrument, warn};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
// use uuid::Uuid;

use squrl_shared::dynamodb::DynamoDbClient as UrlDynamoDbClient;
use squrl_shared::error::UrlShortenerError;
use squrl_shared::models::{AnalyticsEvent, ErrorResponse, RedirectRequest, RedirectResponse};

#[derive(Clone)]
struct AppState {
    db_client: UrlDynamoDbClient,
    kinesis_client: KinesisClient,
    kinesis_stream_name: String,
}

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
            .endpoint_url(endpoint_url.clone())
            .build();
        DynamoDbClient::from_conf(dynamodb_config)
    } else {
        DynamoDbClient::new(&config)
    };
    
    let kinesis_client = if let Ok(endpoint_url) = env::var("AWS_ENDPOINT_URL") {
        // Local development with LocalStack
        let kinesis_config = aws_sdk_kinesis::config::Builder::from(&config)
            .endpoint_url(endpoint_url)
            .build();
        KinesisClient::from_conf(kinesis_config)
    } else {
        KinesisClient::new(&config)
    };
    
    let table_name = env::var("DYNAMODB_TABLE_NAME")
        .unwrap_or_else(|_| "squrl-urls".to_string());
    let kinesis_stream_name = env::var("KINESIS_STREAM_NAME")
        .unwrap_or_else(|_| "squrl-analytics".to_string());
    
    let db_client = UrlDynamoDbClient::new(dynamodb_client, table_name);
    let app_state = AppState {
        db_client,
        kinesis_client,
        kinesis_stream_name,
    };
    
    run(service_fn(move |event| function_handler(event, app_state.clone()))).await
}

#[instrument(skip(app_state))]
async fn function_handler(
    event: LambdaEvent<Value>,
    app_state: AppState,
) -> Result<Value, Error> {
    match handler_impl(event.payload, &app_state).await {
        Ok(response) => Ok(response),
        Err(err) => {
            error!("Function error: {}", err);
            Ok(create_error_response(&err))
        }
    }
}

async fn handler_impl(
    payload: Value,
    app_state: &AppState,
) -> Result<Value, UrlShortenerError> {
    let request: RedirectRequest = serde_json::from_value(payload)
        .map_err(|e| UrlShortenerError::ValidationError(e.to_string()))?;

    info!("Processing redirect request for: {}", request.short_code);

    // Look up the URL
    let url_item = app_state
        .db_client
        .get_url(&request.short_code)
        .await?
        .ok_or_else(|| UrlShortenerError::ShortCodeNotFound(request.short_code.clone()))?;

    // Increment click count asynchronously
    if let Err(e) = app_state.db_client.increment_click_count(&request.short_code).await {
        warn!("Failed to increment click count: {}", e);
    }

    // Send analytics event to Kinesis
    let analytics_event = AnalyticsEvent {
        short_code: request.short_code.clone(),
        timestamp: Utc::now().to_rfc3339(),
        client_ip: request.client_ip,
        user_agent: request.user_agent,
        referer: request.referer,
        country: None, // TODO: Add IP geolocation
        city: None,
    };

    if let Err(e) = send_analytics_event(app_state, &analytics_event).await {
        warn!("Failed to send analytics event: {}", e);
    }

    let response = RedirectResponse {
        original_url: url_item.original_url,
        redirect_type: "301".to_string(),
    };

    Ok(serde_json::to_value(response)?)
}

#[instrument(skip(app_state, event))]
async fn send_analytics_event(
    app_state: &AppState,
    event: &AnalyticsEvent,
) -> Result<(), UrlShortenerError> {
    let event_data = serde_json::to_string(event)
        .map_err(|e| UrlShortenerError::InternalError(e.into()))?;

    app_state
        .kinesis_client
        .put_record()
        .stream_name(&app_state.kinesis_stream_name)
        .partition_key(&event.short_code)
        .data(event_data.into_bytes().into())
        .send()
        .await
        .map_err(|e| UrlShortenerError::InternalError(e.into()))?;

    info!("Analytics event sent successfully");
    Ok(())
}

fn create_error_response(err: &UrlShortenerError) -> Value {
    let error_response = ErrorResponse {
        error: err.error_type().to_string(),
        message: err.to_string(),
        details: None,
    };

    json!({
        "statusCode": err.status_code(),
        "body": serde_json::to_string(&error_response).unwrap(),
        "headers": {
            "Content-Type": "application/json"
        }
    })
}

// Handler removed - using only Lambda runtime handler

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_handler_impl() {
        // Test implementation would go here
        // Requires setting up DynamoDB mock or LocalStack
    }
}