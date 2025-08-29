use aws_sdk_dynamodb::Client;
use aws_sdk_dynamodb::types::AttributeValue;
use chrono::Utc;
use std::collections::HashMap;
use tracing::{info, instrument};

use crate::error::UrlShortenerError;
use crate::models::UrlItem;

#[derive(Clone)]
pub struct DynamoDbClient {
    client: Client,
    table_name: String,
}

impl DynamoDbClient {
    pub fn new(client: Client, table_name: String) -> Self {
        Self { client, table_name }
    }

    #[instrument(skip(self), fields(short_code = %short_code))]
    pub async fn get_url(&self, short_code: &str) -> Result<Option<UrlItem>, UrlShortenerError> {
        info!("Retrieving URL for short code");

        let result = self
            .client
            .get_item()
            .table_name(&self.table_name)
            .key("short_code", AttributeValue::S(short_code.to_string()))
            .send()
            .await
            .map_err(|e| UrlShortenerError::DatabaseError(e.to_string()))?;

        if let Some(item) = result.item {
            let url_item = self.item_to_url_item(item)?;

            // Check if URL has expired
            if let Some(expires_at) = url_item.expires_at {
                let now = Utc::now().timestamp();
                if now > expires_at {
                    return Err(UrlShortenerError::UrlExpired);
                }
            }

            Ok(Some(url_item))
        } else {
            Ok(None)
        }
    }

    #[instrument(skip(self), fields(original_url = %original_url))]
    pub async fn find_existing_url(
        &self,
        original_url: &str,
    ) -> Result<Option<UrlItem>, UrlShortenerError> {
        info!("Checking for existing URL");

        let result = self
            .client
            .query()
            .table_name(&self.table_name)
            .index_name("original_url_index")
            .key_condition_expression("original_url = :url")
            .expression_attribute_values(":url", AttributeValue::S(original_url.to_string()))
            .send()
            .await
            .map_err(|e| UrlShortenerError::DatabaseError(e.to_string()))?;

        if let Some(items) = result.items
            && let Some(item) = items.into_iter().next()
        {
            let url_item = self.item_to_url_item(item)?;
            return Ok(Some(url_item));
        }

        Ok(None)
    }

    #[instrument(skip(self, url_item))]
    pub async fn put_url(&self, url_item: &UrlItem) -> Result<(), UrlShortenerError> {
        info!("Storing URL item");

        let mut item = HashMap::new();
        item.insert(
            "short_code".to_string(),
            AttributeValue::S(url_item.short_code.clone()),
        );
        item.insert(
            "original_url".to_string(),
            AttributeValue::S(url_item.original_url.clone()),
        );
        item.insert(
            "created_at".to_string(),
            AttributeValue::S(url_item.created_at.clone()),
        );
        item.insert(
            "click_count".to_string(),
            AttributeValue::N(url_item.click_count.to_string()),
        );
        item.insert(
            "custom_code".to_string(),
            AttributeValue::Bool(url_item.custom_code),
        );
        item.insert(
            "status".to_string(),
            AttributeValue::S(url_item.status.clone()),
        );

        if let Some(expires_at) = url_item.expires_at {
            item.insert(
                "expires_at".to_string(),
                AttributeValue::N(expires_at.to_string()),
            );
        }

        self.client
            .put_item()
            .table_name(&self.table_name)
            .set_item(Some(item))
            .condition_expression("attribute_not_exists(short_code)")
            .send()
            .await
            .map_err(|e| {
                if e.to_string().contains("ConditionalCheckFailedException") {
                    UrlShortenerError::ShortCodeExists(url_item.short_code.clone())
                } else {
                    UrlShortenerError::DatabaseError(e.to_string())
                }
            })?;

        Ok(())
    }

    #[instrument(skip(self), fields(short_code = %short_code))]
    pub async fn increment_click_count(&self, short_code: &str) -> Result<(), UrlShortenerError> {
        info!("Incrementing click count");

        self.client
            .update_item()
            .table_name(&self.table_name)
            .key("short_code", AttributeValue::S(short_code.to_string()))
            .update_expression("ADD click_count :inc")
            .expression_attribute_values(":inc", AttributeValue::N("1".to_string()))
            .send()
            .await
            .map_err(|e| UrlShortenerError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    fn item_to_url_item(
        &self,
        item: HashMap<String, AttributeValue>,
    ) -> Result<UrlItem, UrlShortenerError> {
        let short_code = item
            .get("short_code")
            .and_then(|v| v.as_s().ok())
            .ok_or_else(|| UrlShortenerError::InternalError(anyhow::anyhow!("Missing short_code")))?
            .clone();

        let original_url = item
            .get("original_url")
            .and_then(|v| v.as_s().ok())
            .ok_or_else(|| {
                UrlShortenerError::InternalError(anyhow::anyhow!("Missing original_url"))
            })?
            .clone();

        let created_at = item
            .get("created_at")
            .and_then(|v| v.as_s().ok())
            .ok_or_else(|| UrlShortenerError::InternalError(anyhow::anyhow!("Missing created_at")))?
            .clone();

        let expires_at = item
            .get("expires_at")
            .and_then(|v| v.as_n().ok())
            .and_then(|s| s.parse().ok());

        let click_count = item
            .get("click_count")
            .and_then(|v| v.as_n().ok())
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);

        let custom_code = item
            .get("custom_code")
            .and_then(|v| v.as_bool().ok().copied())
            .unwrap_or(false);

        let status = item
            .get("status")
            .and_then(|v| v.as_s().ok())
            .map(String::from)
            .unwrap_or_else(|| "active".to_string());

        Ok(UrlItem {
            short_code,
            original_url,
            created_at,
            expires_at,
            click_count,
            custom_code,
            status,
        })
    }
}
