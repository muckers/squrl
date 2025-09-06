use aws_config::BehaviorVersion;
use aws_sdk_dynamodb::Client as DynamoDbClient;
use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::{IntoResponse, Json},
    routing::{get, post},
    Router,
};
use chrono::{DateTime, Utc};
use nanoid::nanoid;
use serde_json::{json, Value};
use std::{env, net::SocketAddr};
use tokio::net::TcpListener;
use tower::ServiceBuilder;
use tower_http::cors::{Any, CorsLayer};
use tracing::{error, info, warn};
use validator::Validate;

use squrl_shared::dynamodb::DynamoDbClient as UrlDynamoDbClient;
use squrl_shared::error::UrlShortenerError;
use squrl_shared::models::{CreateUrlRequest, CreateUrlResponse, UrlItem};
use squrl_shared::validation::{validate_custom_code, validate_url};

#[derive(Clone)]
pub struct AppState {
    db_client: UrlDynamoDbClient,
}

pub async fn run_dev_server() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize AWS config
    let config = aws_config::load_defaults(BehaviorVersion::latest()).await;

    let dynamodb_client = if let Ok(endpoint_url) = env::var("AWS_ENDPOINT_URL") {
        info!("Using LocalStack endpoint: {}", endpoint_url);
        let dynamodb_config = aws_sdk_dynamodb::config::Builder::from(&config)
            .endpoint_url(endpoint_url)
            .build();
        DynamoDbClient::from_conf(dynamodb_config)
    } else {
        info!("Using AWS DynamoDB");
        DynamoDbClient::new(&config)
    };

    let table_name = env::var("DYNAMODB_TABLE_NAME").unwrap_or_else(|_| "squrl-urls".to_string());
    info!("Using DynamoDB table: {}", table_name);

    let db_client = UrlDynamoDbClient::new(dynamodb_client, table_name);
    let app_state = AppState { db_client };

    // Configure CORS to allow web UI to connect
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // Build our application with routes
    let app = Router::new()
        .route("/api/create-url", post(create_url_handler))
        .route("/api/redirect/:short_code", get(redirect_handler))
        .route("/api/stats/:short_code", get(stats_handler))
        .layer(ServiceBuilder::new().layer(cors))
        .with_state(app_state);

    // Start the server
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    let listener = TcpListener::bind(addr).await?;

    info!("🚀 Local development server started!");
    info!("📍 Listening on: http://{}", addr);
    info!("🌐 API endpoints:");
    info!("   • POST http://localhost:3000/api/create-url");
    info!("   • GET  http://localhost:3000/api/redirect/:short_code");
    info!("   • GET  http://localhost:3000/api/stats/:short_code");
    info!("");
    info!("💡 Update your web UI to use: http://localhost:3000/api/");

    axum::serve(listener, app).await?;
    Ok(())
}

async fn create_url_handler(
    State(app_state): State<AppState>,
    Json(payload): Json<CreateUrlRequest>,
) -> impl IntoResponse {
    info!("Received create-url request: {:?}", payload);

    match create_url_impl(payload, &app_state.db_client).await {
        Ok(response) => {
            info!("Create URL successful");
            Json(response).into_response()
        }
        Err(err) => {
            error!("Create URL failed: {}", err);
            let status = match &err {
                UrlShortenerError::ValidationError(_) => StatusCode::BAD_REQUEST,
                UrlShortenerError::ShortCodeExists(_) => StatusCode::CONFLICT,
                _ => StatusCode::INTERNAL_SERVER_ERROR,
            };

            let error_body = json!({
                "error": err.error_type(),
                "message": err.to_string()
            });

            (status, Json(error_body)).into_response()
        }
    }
}

async fn redirect_handler(
    State(app_state): State<AppState>,
    Path(short_code): Path<String>,
) -> impl IntoResponse {
    info!("Received redirect request for: {}", short_code);

    match redirect_impl(short_code.clone(), &app_state.db_client).await {
        Ok(original_url) => {
            info!("Redirect successful to: {}", original_url);
            // Return the redirect URL as JSON for API testing
            // In a real redirect, this would be a 301/302 redirect
            Json(json!({
                "original_url": original_url,
                "redirect_type": "301"
            }))
            .into_response()
        }
        Err(err) => {
            error!("Redirect failed: {}", err);
            let status = match &err {
                UrlShortenerError::ShortCodeNotFound(_) => StatusCode::NOT_FOUND,
                _ => StatusCode::INTERNAL_SERVER_ERROR,
            };

            let error_body = json!({
                "error": err.error_type(),
                "message": err.to_string()
            });

            (status, Json(error_body)).into_response()
        }
    }
}

async fn stats_handler(
    State(app_state): State<AppState>,
    Path(short_code): Path<String>,
) -> impl IntoResponse {
    info!("Received stats request for: {}", short_code);

    match stats_impl(short_code.clone(), &app_state.db_client).await {
        Ok(response) => {
            info!("Stats request successful");
            Json(response).into_response()
        }
        Err(err) => {
            error!("Stats request failed: {}", err);
            let status = match &err {
                UrlShortenerError::ShortCodeNotFound(_) => StatusCode::NOT_FOUND,
                _ => StatusCode::INTERNAL_SERVER_ERROR,
            };

            let error_body = json!({
                "error": err.error_type(),
                "message": err.to_string()
            });

            (status, Json(error_body)).into_response()
        }
    }
}

// Implementation functions that mirror the Lambda handlers

async fn create_url_impl(
    request: CreateUrlRequest,
    db_client: &UrlDynamoDbClient,
) -> Result<CreateUrlResponse, UrlShortenerError> {
    // Validate the request
    request
        .validate()
        .map_err(|e| UrlShortenerError::ValidationError(e.to_string()))?;

    let _validated_url = validate_url(&request.original_url)?;

    if let Some(custom_code) = &request.custom_code {
        validate_custom_code(custom_code)?;
    }

    // Check for existing URL
    if let Some(existing_item) = db_client.find_existing_url(&request.original_url).await? {
        let base_url = env::var("SHORT_URL_BASE").unwrap_or_else(|_| "https://sqrl.co".to_string());
        let short_url = format!("{}/{}", base_url, existing_item.short_code);
        let expires_at = existing_item.expires_at.map(|ts| {
            DateTime::from_timestamp(ts, 0)
                .unwrap_or_else(Utc::now)
                .to_rfc3339()
        });

        return Ok(CreateUrlResponse {
            short_code: existing_item.short_code,
            original_url: existing_item.original_url,
            short_url,
            created_at: existing_item.created_at,
            expires_at,
        });
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

    // Create response
    let base_url = env::var("SHORT_URL_BASE").unwrap_or_else(|_| "https://sqrl.co".to_string());
    let short_url = format!("{}/{}", base_url, url_item.short_code);
    let expires_at = url_item.expires_at.map(|ts| {
        DateTime::from_timestamp(ts, 0)
            .unwrap_or_else(Utc::now)
            .to_rfc3339()
    });

    Ok(CreateUrlResponse {
        short_code: url_item.short_code,
        original_url: url_item.original_url,
        short_url,
        created_at: url_item.created_at,
        expires_at,
    })
}

async fn redirect_impl(
    short_code: String,
    db_client: &UrlDynamoDbClient,
) -> Result<String, UrlShortenerError> {
    // Look up the URL
    let url_item = db_client
        .get_url(&short_code)
        .await?
        .ok_or_else(|| UrlShortenerError::ShortCodeNotFound(short_code.clone()))?;

    // Increment click count asynchronously
    if let Err(e) = db_client.increment_click_count(&short_code).await {
        warn!("Failed to increment click count: {}", e);
    }

    Ok(url_item.original_url)
}

async fn stats_impl(
    short_code: String,
    db_client: &UrlDynamoDbClient,
) -> Result<Value, UrlShortenerError> {
    // Get the URL item from DynamoDB
    let url_item = db_client
        .get_url(&short_code)
        .await?
        .ok_or_else(|| UrlShortenerError::ShortCodeNotFound(short_code.clone()))?;

    Ok(json!({
        "short_code": url_item.short_code,
        "original_url": url_item.original_url,
        "click_count": url_item.click_count,
        "created_at": url_item.created_at,
        "expires_at": url_item.expires_at
    }))
}

fn generate_short_code() -> String {
    // Use nanoid for collision-resistant ID generation
    let id = nanoid!(8, &nanoid::alphabet::SAFE);
    id
}
