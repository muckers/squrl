use rusqlite::OptionalExtension;
use rusqlite::{Connection, Result};

const CHARSET: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const BASE: u64 = 62;

struct UrlShortener {
    conn: Connection,
}

/// A simple URL shortener that generates base62-encoded short codes
impl UrlShortener {
    /// Creates a new UrlShortener instance and initializes the database
    pub fn new() -> Result<Self> {
        let conn = Connection::open("urls.db")?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS urls (
                id INTEGER PRIMARY KEY,
                original_url TEXT NOT NULL,
                short_code TEXT NOT NULL UNIQUE
            )",
            [],
        )?;

        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_original_url ON urls(original_url)",
            [],
        )?;

        Ok(UrlShortener { conn })
    }

    /// Encodes a number into a base62 string
    ///
    fn encode_base62(mut num: u64) -> String {
        if num == 0 {
            return (CHARSET[0] as char).to_string();
        }

        let mut encoded = String::new();
        while num > 0 {
            let remainder = (num % BASE) as usize;
            encoded.insert(0, CHARSET[remainder] as char);
            num /= BASE;
        }
        encoded
    }

    /// Returns the next available ID for a new URL
    /// This is the maximum ID in the database plus one
    fn get_next_id(&mut self) -> Result<u64> {
        self.conn
            .query_row("SELECT COALESCE(MAX(id), 0) + 1 FROM urls", [], |row| {
                row.get(0)
            })
    }

    /// Shortens a URL and returns the generated short code
    /// If the URL already exists, the existing short code is returned
    /// Otherwise, a new short code is generated and returned
    /// The original URL and short code are stored in the database
    /// Returns an error if the database operation fails
    /// or if the URL is not a valid UTF-8 string
    ///
    fn shorten_url(&mut self, original_url: &str) -> Result<String> {
        // Check if URL already exists
        let existing_code: Option<String> = self
            .conn
            .query_row(
                "SELECT short_code FROM urls WHERE original_url = ?",
                [original_url],
                |row| row.get(0),
            )
            .optional()?;

        if let Some(code) = existing_code {
            return Ok(code);
        }

        // Generate new short code
        let next_id = self.get_next_id()?;
        let short_code = Self::encode_base62(next_id);

        // Insert new URL
        self.conn.execute(
            "INSERT INTO urls (original_url, short_code) VALUES (?1, ?2)",
            [original_url, &short_code],
        )?;

        Ok(short_code)
    }

    /// Retrieves the original URL for a given short code
    ///
    fn get_original_url(&self, short_code: &str) -> Result<Option<String>> {
        self.conn
            .query_row(
                "SELECT original_url FROM urls WHERE short_code = ?",
                [short_code],
                |row| row.get(0),
            )
            .optional()
    }
}

fn main() -> Result<()> {
    let mut shortener = UrlShortener::new()?;

    let test_urls = [
        "https://www.example.com/very/long/url/path",
        "https://www.example.com/another/path",
        "https://www.example.com/third/url",
    ];

    for url in test_urls.iter() {
        let short_code = shortener.shorten_url(url)?;
        println!("Original: {}", url);
        println!("Shortened: {}", short_code);

        if let Some(original) = shortener.get_original_url(&short_code)? {
            println!("Retrieved: {}", original);
            assert_eq!(&original, url);
        }
        println!("---");
    }

    let code1 = shortener.shorten_url(test_urls[0])?;
    let code2 = shortener.shorten_url(test_urls[0])?;
    assert_eq!(code1, code2);
    println!("Duplicate test passed: same URL returns same code");

    Ok(())
}
