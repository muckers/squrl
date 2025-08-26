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
use squrl_shared::models::{AnalyticsEvent, ErrorResponse, RedirectRequest, RedirectResponse,
                           ApiGatewayProxyEvent, ApiGatewayProxyResponse, is_api_gateway_event};

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
    let is_api_gateway = is_api_gateway_event(&event.payload);
    
    match handler_impl(event.payload, &app_state).await {
        Ok(response) => {
            if is_api_gateway {
                Ok(create_api_gateway_redirect_response(response))
            } else {
                Ok(response)
            }
        }
        Err(err) => {
            error!("Function error: {}", err);
            Ok(create_error_response(&err, is_api_gateway))
        }
    }
}

async fn handler_impl(
    payload: Value,
    app_state: &AppState,
) -> Result<Value, UrlShortenerError> {
    let (short_code, client_ip, user_agent, referer, http_method) = if is_api_gateway_event(&payload) {
        // Parse API Gateway event
        let api_event: ApiGatewayProxyEvent = serde_json::from_value(payload)
            .map_err(|e| UrlShortenerError::ValidationError(format!("Invalid API Gateway event: {}", e)))?;
        
        // Extract short_code from path parameters
        let short_code = api_event.path_parameters
            .as_ref()
            .and_then(|params| params.get("short_code"))
            .ok_or_else(|| UrlShortenerError::ValidationError("Missing short_code in path parameters".to_string()))?
            .clone();
            
        // Extract client information from request context and headers
        let client_ip = api_event.request_context
            .as_ref()
            .and_then(|ctx| ctx.identity.as_ref())
            .and_then(|identity| identity.source_ip.clone());
            
        let user_agent = api_event.headers
            .as_ref()
            .and_then(|headers| headers.get("User-Agent").or_else(|| headers.get("user-agent")))
            .cloned();
            
        let referer = api_event.headers
            .as_ref()
            .and_then(|headers| headers.get("Referer").or_else(|| headers.get("referer")))
            .cloned();
            
        let http_method = api_event.http_method.clone();
            
        (short_code, client_ip, user_agent, referer, http_method)
    } else {
        // Direct Lambda invocation
        let request: RedirectRequest = serde_json::from_value(payload)
            .map_err(|e| UrlShortenerError::ValidationError(e.to_string()))?;
            
        (request.short_code, request.client_ip, request.user_agent, request.referer, "GET".to_string())
    };

    info!("Processing redirect request for: {}", short_code);

    // Look up the URL
    let url_item = app_state
        .db_client
        .get_url(&short_code)
        .await?
        .ok_or_else(|| UrlShortenerError::ShortCodeNotFound(short_code.clone()))?;

    // For HEAD requests, we skip analytics and click count increments
    // as they're typically used just to check if a URL exists
    if http_method != "HEAD" {
        // Increment click count asynchronously
        if let Err(e) = app_state.db_client.increment_click_count(&short_code).await {
            warn!("Failed to increment click count: {}", e);
        }

        // Send analytics event to Kinesis
        let analytics_event = AnalyticsEvent {
            short_code: short_code.clone(),
            timestamp: Utc::now().to_rfc3339(),
            client_ip,
            user_agent,
            referer,
            country: None, // TODO: Add IP geolocation
            city: None,
        };

        if let Err(e) = send_analytics_event(app_state, &analytics_event).await {
            warn!("Failed to send analytics event: {}", e);
        }
    } else {
        info!("HEAD request - skipping analytics and click count");
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

fn create_api_gateway_redirect_response(response_data: Value) -> Value {
    // Extract the original_url from the response data
    if let Some(original_url) = response_data.get("original_url").and_then(|v| v.as_str()) {
        let api_response = ApiGatewayProxyResponse::redirect(original_url.to_string());
        serde_json::to_value(api_response).unwrap()
    } else {
        // Fallback to error response if URL not found
        let api_response = ApiGatewayProxyResponse::new(
            500,
            json!({"error": "Internal error", "message": "Failed to extract redirect URL"}).to_string()
        );
        serde_json::to_value(api_response).unwrap()
    }
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
            serde_json::to_string(&error_response).unwrap()
        );
        serde_json::to_value(api_response).unwrap()
    } else {
        json!({
            "statusCode": err.status_code(),
            "body": serde_json::to_string(&error_response).unwrap(),
            "headers": {
                "Content-Type": "application/json"
            }
        })
    }
}

// Handler removed - using only Lambda runtime handler

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[tokio::test]
    async fn test_handler_impl() {
        // Test implementation would go here
        // Requires setting up DynamoDB mock or LocalStack
    }

    #[test]
    fn test_api_gateway_redirect_response() {
        let redirect_data = json!({
            "original_url": "https://example.com",
            "redirect_type": "301"
        });
        
        let api_response = create_api_gateway_redirect_response(redirect_data);
        
        assert_eq!(api_response["statusCode"], 301);
        assert!(api_response["headers"].is_object());
        assert_eq!(api_response["headers"]["Location"], "https://example.com");
        assert_eq!(api_response["body"], "");
    }

    #[test]
    fn test_api_gateway_error_response() {
        let error = UrlShortenerError::ShortCodeNotFound("abc123".to_string());
        let api_response_value = create_error_response(&error, true);
        
        assert_eq!(api_response_value["statusCode"], 404);
        assert!(api_response_value["headers"].is_object());
        assert!(api_response_value["body"].is_string());
        
        // Test legacy response format
        let legacy_response_value = create_error_response(&error, false);
        assert_eq!(legacy_response_value["statusCode"], 404);
        assert_eq!(legacy_response_value["headers"]["Content-Type"], "application/json");
    }

    #[test] 
    fn test_path_parameter_extraction() {
        let api_gateway_event = json!({
            "httpMethod": "GET",
            "pathParameters": {
                "short_code": "abc123"
            },
            "headers": {
                "User-Agent": "Mozilla/5.0",
                "Referer": "https://social.com"
            },
            "requestContext": {
                "identity": {
                    "sourceIp": "192.168.1.1"
                }
            }
        });
        
        assert!(is_api_gateway_event(&api_gateway_event));
        
        // This would be tested in a full integration test with mock DynamoDB
        // For now, we just verify the event is detected as API Gateway
    }
}