# Squrl PopClip Extension

A PopClip extension for quickly shortening URLs and text snippets using the Squrl URL shortener service.

## Features

- **URL Shortening**: Select any URL and instantly create a shortened link
- **Text Snippet Sharing**: Convert selected text into a shareable link
- **Batch Processing**: Shorten multiple URLs at once
- **Configurable Endpoints**: Switch between production, staging, or custom API endpoints
- **Customizable TTL**: Set expiration time for shortened links
- **Smart Notifications**: Optional success/error notifications

## Installation

### Method 1: Double-Click Install
1. Download the `squrl.popclipext` folder
2. Double-click the folder to install in PopClip
3. The extension will appear in PopClip's extension list

### Method 2: Manual Install
1. Open PopClip preferences
2. Click the "+" button
3. Select "Install Extension..."
4. Navigate to and select the `squrl.popclipext` folder

### Method 3: Build from Source
```bash
# From the squrl project root
just build-popclip

# This creates a packaged extension at:
# popclip-extension/squrl.popclipextz
```

## Usage

### Shortening URLs
1. Select any URL in any application
2. Click the PopClip bar when it appears
3. Click the "Shorten URL" button (link icon)
4. The shortened URL is automatically copied to your clipboard

### Creating Links from Text
1. Select any text (non-URL)
2. Click the PopClip bar
3. Click the "Create Link from Text" button
4. A shareable link containing your text is created and copied

### Batch URL Shortening
1. Select text containing multiple URLs
2. Click the "Shorten All URLs" button
3. All URLs are shortened and the results are copied to clipboard

## Configuration Options

Access settings through PopClip preferences → Extensions → Squrl → Settings

### Service Endpoint
- **Production**: Uses https://squrl.pub (default)
- **Staging**: Uses https://staging.squrl.pub
- **Custom**: Use your own Squrl instance

### Custom API URL
When using custom endpoint, specify your API URL (must use HTTPS)

### Link Expiry (hours)
- Default: 8760 (1 year)
- Minimum: 1 hour
- Maximum: 87600 hours (10 years)

### Show Notifications
Toggle success/error notifications on or off

## Actions

The extension provides three context-aware actions:

1. **Shorten URL** - Appears when a URL is selected
2. **Create Link from Text** - Appears for non-URL text
3. **Shorten All URLs** - Appears when multiple URLs are detected

## Keyboard Shortcuts

You can assign keyboard shortcuts to Squrl actions in PopClip preferences:
1. Go to PopClip Preferences → Extensions
2. Select Squrl
3. Click on an action
4. Press your desired keyboard combination

## API Requirements

The extension communicates with Squrl API endpoints that accept:
```json
{
  "original_url": "https://example.com/long-url",
  "ttl_hours": 8760,
  "custom_code": "optional-custom-code"
}
```

And return:
```json
{
  "short_url": "https://squrl.pub/abc123",
  "short_code": "abc123",
  "original_url": "https://example.com/long-url",
  "expires_at": "2025-01-01T00:00:00Z"
}
```

## Troubleshooting

### Extension Not Appearing
- Ensure PopClip is running (check menu bar)
- Verify extension is enabled in PopClip preferences
- Try reinstalling the extension

### Network Errors
- Check your internet connection
- Verify the API endpoint is accessible
- For custom endpoints, ensure HTTPS is used

### Rate Limiting
If you see "Rate limit exceeded":
- Wait a few minutes before trying again
- The default limit is 500 requests per 5 minutes

### Invalid URL Format
- Ensure the selected text is a valid URL
- URLs must start with http://, https://, or be recognizable web addresses

## Privacy & Security

- The extension only sends data to configured Squrl endpoints
- No data is stored locally except your configuration preferences
- All API communication uses HTTPS
- No authentication tokens or personal data are transmitted

## Development

### Building from Source

1. Clone the repository
2. Navigate to `popclip-extension/`
3. Make modifications to `Config.yaml` or `squrl.js`
4. Test locally by double-clicking the `.popclipext` folder

### Debug Mode

Enable debug output for troubleshooting:
```bash
defaults write com.pilotmoon.popclip EnableExtensionDebug -bool YES
```

View debug output in Console.app

### Creating a Signed Package

```bash
# Create a .popclipextz (zipped) package
just package-popclip

# Sign the package (requires developer certificate)
just sign-popclip
```

## Version History

### 1.0.0 (2025-01-16)
- Initial release
- URL shortening support
- Text snippet sharing
- Batch processing
- Configurable endpoints

## Support

For issues or feature requests:
- GitHub: https://github.com/[your-username]/squrl
- PopClip Forums: https://forum.popclip.app

## License

This extension is part of the Squrl project and follows the same license terms.

## Credits

- Squrl URL Shortener: https://squrl.pub
- PopClip by Pilotmoon Software: https://pilotmoon.com/popclip/

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

For major changes, please open an issue first to discuss the proposed changes.