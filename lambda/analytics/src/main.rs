use aws_config::BehaviorVersion;
use aws_lambda_events::event::kinesis::KinesisEvent;
use aws_sdk_dynamodb::Client as DynamoDbClient;
use aws_sdk_secretsmanager::Client as SecretsManagerClient;
use lambda_runtime::{run, service_fn, Error, LambdaEvent};
use serde_json::Value;
use std::env;
use tracing::{error, info, instrument, warn};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use squrl_shared::dynamodb::DynamoDbClient as UrlDynamoDbClient;
use squrl_shared::error::UrlShortenerError;
use squrl_shared::models::AnalyticsEvent;
use squrl_shared::secrets::{SecretsManagerConfig, AppConfig};

#[derive(Clone)]
struct AppState {
    db_client: UrlDynamoDbClient,
    app_config: AppConfig,
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
    
    // Initialize AWS clients
    let dynamodb_client = if let Ok(endpoint_url) = env::var("AWS_ENDPOINT_URL") {
        // Local development with LocalStack
        let dynamodb_config = aws_sdk_dynamodb::config::Builder::from(&config)
            .endpoint_url(endpoint_url.clone())
            .build();
        DynamoDbClient::from_conf(dynamodb_config)
    } else {
        DynamoDbClient::new(&config)
    };

    let secrets_client = if let Ok(endpoint_url) = env::var("AWS_ENDPOINT_URL") {
        // Local development with LocalStack
        let secrets_config = aws_sdk_secretsmanager::config::Builder::from(&config)
            .endpoint_url(endpoint_url)
            .build();
        Some(SecretsManagerConfig::new(SecretsManagerClient::from_conf(secrets_config)))
    } else {
        Some(SecretsManagerConfig::new(SecretsManagerClient::new(&config)))
    };

    // Load application configuration from Secrets Manager with fallback to env vars
    info!("Loading application configuration...");
    let app_config = AppConfig::load_auto(secrets_client.as_ref()).await
        .map_err(|e| {
            error!("Failed to load application configuration: {}", e);
            format!("Configuration error: {}", e)
        })?;

    info!(
        table_name = %app_config.dynamodb_table_name,
        "Application configuration loaded successfully"
    );
    
    let db_client = UrlDynamoDbClient::new(dynamodb_client, app_config.dynamodb_table_name.clone());
    let app_state = AppState { db_client, app_config };
    
    run(service_fn(move |event| function_handler(event, app_state.clone()))).await
}

#[instrument(skip(app_state))]
async fn function_handler(
    event: LambdaEvent<KinesisEvent>,
    app_state: AppState,
) -> Result<Value, Error> {
    info!("Processing {} Kinesis records", event.payload.records.len());
    
    for record in event.payload.records {
        let data = &record.kinesis.data;
        match process_analytics_record(data, &app_state).await {
            Ok(_) => info!("Successfully processed analytics record"),
            Err(e) => error!("Failed to process analytics record: {}", e),
        }
    }

    Ok(serde_json::json!({
        "statusCode": 200,
        "body": "Analytics processed successfully"
    }))
}

async fn process_analytics_record(
    data: &aws_lambda_events::encodings::Base64Data,
    app_state: &AppState,
) -> Result<(), UrlShortenerError> {
    let decoded_data = std::str::from_utf8(data.as_ref())
        .map_err(|e| UrlShortenerError::ValidationError(format!("UTF-8 decode error: {}", e)))?;
        
    let analytics_event: AnalyticsEvent = serde_json::from_str(decoded_data)
        .map_err(|e| UrlShortenerError::ValidationError(e.to_string()))?;

    info!("Processing analytics for short code: {}", analytics_event.short_code);

    // In Phase 1, we just log the analytics event
    // In later phases, we'll store this in a separate analytics table
    // or process it for real-time dashboards
    
    info!(
        short_code = %analytics_event.short_code,
        timestamp = %analytics_event.timestamp,
        client_ip = ?analytics_event.client_ip,
        user_agent = ?analytics_event.user_agent,
        referer = ?analytics_event.referer,
        "Analytics event processed"
    );

    // TODO: Store in analytics table or send to data pipeline
    // For now, we'll just ensure the URL still exists
    match app_state.db_client.get_url(&analytics_event.short_code).await {
        Ok(Some(_)) => {
            info!("URL found for analytics event");
        }
        Ok(None) => {
            warn!("URL not found for analytics event: {}", analytics_event.short_code);
        }
        Err(e) => {
            error!("Database error while validating URL: {}", e);
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_process_analytics_record() {
        let analytics_json = r#"{
            "short_code": "test123",
            "timestamp": "2025-08-24T10:30:00Z",
            "client_ip": "192.168.1.1",
            "user_agent": "Mozilla/5.0",
            "referer": "https://social.com",
            "country": null,
            "city": null
        }"#;

        // Test parsing
        let event: AnalyticsEvent = serde_json::from_str(analytics_json).unwrap();
        assert_eq!(event.short_code, "test123");
    }
}