// Squrl PopClip Extension - Main JavaScript Module
// This module provides URL shortening functionality via the Squrl API

const axios = require('axios');

// API endpoint configurations
const API_ENDPOINTS = {
  production: 'https://squrl.pub/create',
  staging: 'https://staging.squrl.pub/create'
};

// Helper function to determine the correct API endpoint
function getApiEndpoint(options) {
  const endpoint = options.endpoint || 'production';
  const customUrl = options.custom_url;

  if (endpoint === 'custom' && customUrl) {
    // Validate custom URL
    if (!customUrl.startsWith('https://')) {
      throw new Error('Custom URL must use HTTPS');
    }
    return customUrl;
  }

  return API_ENDPOINTS[endpoint] || API_ENDPOINTS.production;
}

// Helper function to format error messages
function formatError(error) {
  if (error.response) {
    // Server responded with error
    const status = error.response.status;
    const data = error.response.data;

    if (status === 400) {
      return 'Invalid URL format';
    } else if (status === 429) {
      return 'Rate limit exceeded';
    } else if (status === 500) {
      return 'Server error';
    } else if (data && data.error) {
      return data.error;
    }
    return `Error: ${status}`;
  } else if (error.request) {
    // Request made but no response
    return 'Network error - check connection';
  } else if (error.message) {
    return error.message;
  }
  return 'Unknown error occurred';
}

// Main function to shorten a single URL
async function shortenUrl(url, options) {
  const apiUrl = getApiEndpoint(options);
  const ttlHours = parseInt(options.ttl_hours) || 8760;

  const requestData = {
    original_url: url,
    ttl_hours: ttlHours
  };

  // Add custom code if provided in options
  if (options.custom_code) {
    requestData.custom_code = options.custom_code;
  }

  const response = await axios.post(apiUrl, requestData, {
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'PopClip-Squrl/1.0'
    },
    timeout: 5000,
    validateStatus: function (status) {
      // Don't throw on any status, we'll handle it
      return true;
    }
  });

  if (response.status === 200 || response.status === 201) {
    if (response.data && response.data.short_url) {
      return {
        success: true,
        shortUrl: response.data.short_url,
        shortCode: response.data.short_code,
        expiresAt: response.data.expires_at
      };
    }
    throw new Error('Invalid response format');
  } else {
    // Handle known error cases
    throw {
      response: response,
      request: true
    };
  }
}

// Function to validate URL format
function isValidUrl(string) {
  try {
    const url = new URL(string);
    return url.protocol === 'http:' || url.protocol === 'https:' || url.protocol === 'data:';
  } catch (_) {
    return false;
  }
}

// Function to create a shareable text snippet
function createTextSnippetUrl(text) {
  // Create a data URL for the text content
  // This allows sharing text snippets as URLs
  const encodedText = encodeURIComponent(text);
  return `data:text/plain;charset=utf-8,${encodedText}`;
}

// Export the main functionality
module.exports = {
  shortenUrl,
  getApiEndpoint,
  formatError,
  isValidUrl,
  createTextSnippetUrl,
  API_ENDPOINTS
};