use aws_config::BehaviorVersion;
use aws_lambda_events::apigw::{ApiGatewayProxyRequest, ApiGatewayProxyResponse};
use aws_lambda_events::http::HeaderMap;
use aws_sdk_dynamodb::Client as DynamoDbClient;
use lambda_runtime::{Error, LambdaEvent, run, service_fn};
use serde::Serialize;
use std::env;
use tracing::{error, info, instrument};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use squrl_shared::dynamodb::DynamoDbClient as UrlDynamoDbClient;
use squrl_shared::error::UrlShortenerError;

#[derive(Clone)]
struct AppState {
    db_client: UrlDynamoDbClient,
}

#[derive(Debug, Serialize)]
struct StatsResponse {
    short_code: String,
    original_url: String,
    click_count: u64,
    created_at: String,
    expires_at: Option<i64>,
}

fn init_tracing() {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(
            std::env::var("RUST_LOG").unwrap_or_else(|_| "info".into()),
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

    let table_name = env::var("DYNAMODB_TABLE_NAME").unwrap_or_else(|_| "squrl-urls".to_string());

    let db_client = UrlDynamoDbClient::new(dynamodb_client, table_name);
    let app_state = AppState { db_client };

    run(service_fn(move |event| {
        function_handler(event, app_state.clone())
    }))
    .await
}

#[instrument(skip(app_state), fields(request_id = %event.context.request_id))]
async fn function_handler(
    event: LambdaEvent<ApiGatewayProxyRequest>,
    app_state: AppState,
) -> Result<ApiGatewayProxyResponse, Error> {
    info!("Handling stats request");

    // Extract short_code from path parameters
    let short_code = event
        .payload
        .path_parameters
        .get("short_code")
        .ok_or_else(|| {
            error!("Missing short_code in path parameters");
            UrlShortenerError::ValidationError("Missing short_code parameter".to_string())
        })?;

    info!("Fetching stats for short_code: {}", short_code);

    // Get the URL item from DynamoDB
    match app_state.db_client.get_url(short_code).await {
        Ok(Some(url_item)) => {
            info!("Found URL item for short_code: {}", short_code);
            
            let stats_response = StatsResponse {
                short_code: url_item.short_code.clone(),
                original_url: url_item.original_url.clone(),
                click_count: url_item.click_count,
                created_at: url_item.created_at.clone(),
                expires_at: url_item.expires_at.clone(),
            };

            let response_body = serde_json::to_string(&stats_response)?;

            Ok(ApiGatewayProxyResponse {
                status_code: 200,
                headers: create_cors_headers(),
                body: Some(aws_lambda_events::encodings::Body::Text(response_body)),
                ..Default::default()
            })
        }
        Ok(None) => {
            info!("URL not found for short_code: {}", short_code);
            
            let error_response = serde_json::json!({
                "error": "URL not found",
                "short_code": short_code
            });

            Ok(ApiGatewayProxyResponse {
                status_code: 404,
                headers: create_cors_headers(),
                body: Some(aws_lambda_events::encodings::Body::Text(error_response.to_string())),
                ..Default::default()
            })
        }
        Err(e) => {
            error!("Error fetching URL stats: {}", e);
            
            let error_response = serde_json::json!({
                "error": "Internal server error"
            });

            Ok(ApiGatewayProxyResponse {
                status_code: 500,
                headers: create_cors_headers(),
                body: Some(aws_lambda_events::encodings::Body::Text(error_response.to_string())),
                ..Default::default()
            })
        }
    }
}

fn create_cors_headers() -> HeaderMap {
    let mut headers = HeaderMap::new();
    headers.insert("Content-Type", "application/json".parse().unwrap());
    headers.insert("Access-Control-Allow-Origin", "*".parse().unwrap());
    headers.insert(
        "Access-Control-Allow-Methods",
        "GET, OPTIONS".parse().unwrap(),
    );
    headers.insert(
        "Access-Control-Allow-Headers",
        "Content-Type".parse().unwrap(),
    );
    headers
}