use crate::error::UrlShortenerError;
use url::Url;

pub fn validate_url(url_str: &str) -> Result<Url, UrlShortenerError> {
    let url =
        Url::parse(url_str).map_err(|_| UrlShortenerError::InvalidUrl(url_str.to_string()))?;

    match url.scheme() {
        "http" | "https" => Ok(url),
        _ => Err(UrlShortenerError::InvalidUrl(
            "Only HTTP and HTTPS URLs are allowed".to_string(),
        )),
    }
}

pub fn validate_custom_code(code: &str) -> Result<(), UrlShortenerError> {
    if code.len() < 3 || code.len() > 20 {
        return Err(UrlShortenerError::ValidationError(
            "Custom code must be between 3 and 20 characters".to_string(),
        ));
    }

    if !code
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
    {
        return Err(UrlShortenerError::ValidationError(
            "Custom code can only contain letters, numbers, underscores, and hyphens".to_string(),
        ));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_url_valid() {
        assert!(validate_url("https://example.com").is_ok());
        assert!(validate_url("http://localhost:3000").is_ok());
    }

    #[test]
    fn test_validate_url_invalid() {
        assert!(validate_url("ftp://example.com").is_err());
        assert!(validate_url("not-a-url").is_err());
    }

    #[test]
    fn test_validate_custom_code_valid() {
        assert!(validate_custom_code("abc123").is_ok());
        assert!(validate_custom_code("test_code").is_ok());
        assert!(validate_custom_code("my-code").is_ok());
    }

    #[test]
    fn test_validate_custom_code_invalid() {
        assert!(validate_custom_code("ab").is_err()); // Too short
        assert!(validate_custom_code("a".repeat(21).as_str()).is_err()); // Too long
        assert!(validate_custom_code("test@code").is_err()); // Invalid character
    }
}
