use aws_config::BehaviorVersion;
use aws_sdk_dynamodb::Client as DynamoDbClient;
use lambda_runtime::{Error, LambdaEvent, run, service_fn};
use serde::Serialize;
use serde_json::{Value, json};
use std::env;
use tracing::{error, info, instrument};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use squrl_shared::dynamodb::DynamoDbClient as UrlDynamoDbClient;
use squrl_shared::error::UrlShortenerError;
use squrl_shared::models::{
    ApiGatewayProxyEvent, ApiGatewayProxyResponse, ErrorResponse, is_api_gateway_event,
};

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
async fn function_handler(event: LambdaEvent<Value>, app_state: AppState) -> Result<Value, Error> {
    info!("Handling stats request");

    let is_api_gateway = is_api_gateway_event(&event.payload);
    let is_local_http = env::var("CARGO_LAMBDA_INVOKE_PORT").is_ok();

    match handler_impl(event.payload, &app_state).await {
        Ok(response) => {
            // Always return API Gateway format for local HTTP server or actual API Gateway
            if is_api_gateway || is_local_http {
                Ok(create_api_gateway_stats_response(response))
            } else {
                Ok(response)
            }
        }
        Err(err) => {
            error!("Function error: {}", err);
            Ok(create_error_response(&err, is_api_gateway || is_local_http))
        }
    }
}

async fn handler_impl(payload: Value, app_state: &AppState) -> Result<Value, UrlShortenerError> {
    let short_code = if is_api_gateway_event(&payload) {
        // Parse API Gateway event
        let api_event: ApiGatewayProxyEvent = serde_json::from_value(payload).map_err(|e| {
            UrlShortenerError::ValidationError(format!("Invalid API Gateway event: {}", e))
        })?;

        // Extract short_code from path parameters
        api_event
            .path_parameters
            .as_ref()
            .and_then(|params| params.get("short_code"))
            .ok_or_else(|| {
                UrlShortenerError::ValidationError(
                    "Missing short_code in path parameters".to_string(),
                )
            })?
            .clone()
    } else {
        // Direct Lambda invocation - expect short_code in payload
        payload
            .get("short_code")
            .and_then(|v| v.as_str())
            .ok_or_else(|| {
                UrlShortenerError::ValidationError("Missing short_code in payload".to_string())
            })?
            .to_string()
    };

    info!("Fetching stats for short_code: {}", short_code);

    // Get the URL item from DynamoDB
    let url_item = app_state
        .db_client
        .get_url(&short_code)
        .await?
        .ok_or_else(|| UrlShortenerError::ShortCodeNotFound(short_code.clone()))?;

    info!("Found URL item for short_code: {}", short_code);

    let stats_response = StatsResponse {
        short_code: url_item.short_code.clone(),
        original_url: url_item.original_url.clone(),
        click_count: url_item.click_count,
        created_at: url_item.created_at.clone(),
        expires_at: url_item.expires_at,
    };

    Ok(serde_json::to_value(stats_response)?)
}

fn create_api_gateway_stats_response(response_data: Value) -> Value {
    let api_response = ApiGatewayProxyResponse::new(200, response_data.to_string());
    serde_json::to_value(api_response).unwrap_or_else(|_| json!({"statusCode": 500, "body": "{}"}))
}

fn create_error_response(error: &UrlShortenerError, is_api_gateway: bool) -> Value {
    let (status_code, error_message) = match error {
        UrlShortenerError::ShortCodeNotFound(code) => {
            (404, format!("URL not found for short code: {}", code))
        }
        UrlShortenerError::ValidationError(msg) => (400, msg.clone()),
        _ => (500, "Internal server error".to_string()),
    };

    if is_api_gateway {
        let error_response = ErrorResponse {
            error: "error".to_string(),
            message: error_message,
            details: None,
        };
        let error_json =
            serde_json::to_string(&error_response).unwrap_or_else(|_| "{}".to_string());
        let api_response = ApiGatewayProxyResponse::new(status_code, error_json);
        serde_json::to_value(api_response)
            .unwrap_or_else(|_| json!({"statusCode": 500, "body": "{}"}))
    } else {
        json!({
            "error": "error",
            "message": error_message
        })
    }
}
