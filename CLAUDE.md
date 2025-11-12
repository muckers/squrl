# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a URL shortener prototype written in Rust with a serverless architecture. The project includes:
- A shared library (`shared/`) with common models and utilities
- AWS Lambda functions (`lambda/`) for create-url, redirect, and get-stats operations
- Terraform infrastructure configuration (`terraform/`) for AWS deployment

## Architecture

### Core Components

1. **Shared Library** (`shared/`): Common functionality including:
   - `models.rs`: Data structures for URL items, requests, and responses
   - `dynamodb.rs`: DynamoDB client wrapper and operations
   - `error.rs`: Custom error types and handling
   - `validation.rs`: URL and input validation logic

2. **Lambda Functions** (`lambda/`):
   - **create-url**: Creates shortened URLs and stores them in DynamoDB
   - **redirect**: Handles URL redirects and updates click counts in DynamoDB
   - **get-stats**: Retrieves statistics for shortened URLs

3. **Database Schema**: DynamoDB table with:
   - `short_code`: Partition key for fast lookups
   - `original_url`: The full URL (with GSI for deduplication)
   - `created_at`, `expires_at`, `click_count`: Metadata fields

4. **AWS Infrastructure** (managed via Terraform):
   - DynamoDB table for URL storage
   - Lambda functions for URL operations
   - API Gateway for HTTP endpoints
   - IAM roles and policies

## Development Commands

The project uses `just` (justfile) for task management, replacing the old Makefile. cargo-lambda is used for building Lambda functions.

### Build Commands
```bash
# Build all Lambda functions for deployment
just build

# Build a specific Lambda function
just build-function create-url
just build-function redirect
just build-function get-stats

# Check build status and artifacts
just status
```

### Testing and Code Quality
```bash
# Run all tests
just test

# Run clippy for linting
just lint

# Format code
just fmt

# Clean build artifacts
just clean
```

### Local Development
```bash
# Set up local infrastructure (LocalStack)
just local-infra

# Run Lambda functions locally (in separate terminals)
just run-local-create-url    # Port 9001
just run-local-redirect      # Port 9002
```

### Deployment
```bash
# Deploy to development environment
just deploy-dev

# Deploy to production environment
just deploy-prod

# Destroy development environment
just destroy-dev
```

### Database
- **Local Development**: Uses LocalStack with mock DynamoDB
- **Production**: Uses AWS DynamoDB with Terraform-managed tables

## Key Implementation Details

- **ID Generation**: Uses nanoid for collision-resistant short codes
- **Deduplication**: Returns existing short code if URL already exists (via GSI on original_url)
- **Click Tracking**: Direct updates to DynamoDB click_count field on redirect
- **Error Handling**: Custom error types with proper HTTP status codes
- **Observability**: Structured logging with tracing, CloudWatch integration
- **Runtime**: Uses `provided.al2` runtime with cargo-lambda for optimal performance

## Build System

The project uses **cargo-lambda** for building Lambda functions, which is the modern, Rust-idiomatic way to build and deploy Lambda functions. This replaces the previous Makefile-based approach.

### cargo-lambda Benefits:
- Native Rust tooling integration
- Optimized for AWS Lambda runtime
- Automatic cross-compilation for `provided.al2`
- Built-in local testing capabilities
- Simplified deployment workflow

### Prerequisites:
```bash
# Install cargo-lambda (if not already installed)
pip install cargo-lambda

# Install just for task management
cargo install just

# Install awslocal for local testing
pip install awscli-local[ver1]
```