#!/bin/bash

# Lambda Build Testing Script
# Tests cargo-lambda builds and validates Lambda deployment packages

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS") echo -e "${GREEN}✅ ${message}${NC}" ;;
        "ERROR") echo -e "${RED}❌ ${message}${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  ${message}${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  ${message}${NC}" ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    print_status "INFO" "Checking Lambda build prerequisites..."
    
    local missing_deps=0
    
    # Check cargo-lambda
    if command -v cargo-lambda &> /dev/null; then
        local cl_version=$(cargo lambda --version)
        print_status "SUCCESS" "Found $cl_version"
    else
        print_status "ERROR" "cargo-lambda is not installed"
        print_status "INFO" "Install with: pip install cargo-lambda"
        ((missing_deps++))
    fi
    
    # Check Docker (cargo-lambda uses it for cross-compilation)
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            print_status "SUCCESS" "Docker is running"
        else
            print_status "WARNING" "Docker is not running - some builds may use Zig fallback"
        fi
    else
        print_status "WARNING" "Docker not found - builds will use Zig fallback"
    fi
    
    # Check zip utility
    if command -v zip &> /dev/null; then
        print_status "SUCCESS" "zip utility found"
    else
        print_status "ERROR" "zip utility is not installed"
        ((missing_deps++))
    fi
    
    # Check Rust target
    if rustup target list --installed | grep -q "x86_64-unknown-linux-musl"; then
        print_status "SUCCESS" "Linux MUSL target installed"
    else
        print_status "WARNING" "Linux MUSL target not installed, installing..."
        rustup target add x86_64-unknown-linux-musl
    fi
    
    return $missing_deps
}

# Function to clean build artifacts
clean_build_artifacts() {
    print_status "INFO" "Cleaning previous build artifacts..."
    
    # Clean cargo build artifacts
    cargo clean
    
    # Remove old Lambda artifacts
    rm -rf target/lambda
    rm -rf target/lambda-packages
    
    # Remove old zip files
    find . -name "bootstrap.zip" -delete 2>/dev/null || true
    
    print_status "SUCCESS" "Build artifacts cleaned"
}

# Function to build a specific Lambda function
build_lambda_function() {
    local function_name=$1
    local log_file="build-${function_name}.log"
    
    print_status "INFO" "Building Lambda function: $function_name"
    
    # Build with cargo-lambda
    if cargo lambda build --release --target x86_64-unknown-linux-musl --bin "$function_name" > "$log_file" 2>&1; then
        print_status "SUCCESS" "$function_name built successfully"
        
        # Verify bootstrap file exists
        local bootstrap_path="target/lambda/$function_name/bootstrap"
        if [[ -f "$bootstrap_path" ]]; then
            local file_size=$(stat -f%z "$bootstrap_path" 2>/dev/null || stat -c%s "$bootstrap_path" 2>/dev/null || echo "unknown")
            print_status "SUCCESS" "Bootstrap binary created: ${file_size} bytes"
            
            # Check if binary is executable
            if [[ -x "$bootstrap_path" ]]; then
                print_status "SUCCESS" "Bootstrap binary is executable"
            else
                print_status "WARNING" "Bootstrap binary is not executable"
                chmod +x "$bootstrap_path"
            fi
            
            # Create deployment package
            local zip_path="target/lambda/$function_name/bootstrap.zip"
            if zip -j "$zip_path" "$bootstrap_path" > "zip-${function_name}.log" 2>&1; then
                local zip_size=$(stat -f%z "$zip_path" 2>/dev/null || stat -c%s "$zip_path" 2>/dev/null || echo "unknown")
                print_status "SUCCESS" "Deployment package created: ${zip_size} bytes"
                
                # Validate zip contents
                if zip -t "$zip_path" > "validate-${function_name}.log" 2>&1; then
                    print_status "SUCCESS" "Deployment package is valid"
                else
                    print_status "ERROR" "Deployment package is corrupted"
                    return 1
                fi
            else
                print_status "ERROR" "Failed to create deployment package"
                cat "zip-${function_name}.log"
                return 1
            fi
        else
            print_status "ERROR" "Bootstrap binary not found at $bootstrap_path"
            return 1
        fi
    else
        print_status "ERROR" "Failed to build $function_name"
        echo "Build log:"
        cat "$log_file"
        return 1
    fi
}

# Function to test Lambda runtime compatibility
test_lambda_runtime() {
    local function_name=$1
    local bootstrap_path="target/lambda/$function_name/bootstrap"
    
    print_status "INFO" "Testing Lambda runtime compatibility for $function_name"
    
    # Check file type
    local file_type=$(file "$bootstrap_path" 2>/dev/null || echo "unknown")
    print_status "INFO" "Binary type: $file_type"
    
    # Check if it's a Linux binary
    if echo "$file_type" | grep -q "Linux"; then
        print_status "SUCCESS" "Binary is compatible with Linux runtime"
    else
        print_status "WARNING" "Binary may not be compatible with Linux runtime"
    fi
    
    # Check for dynamic dependencies (should be minimal for MUSL static build)
    if command -v ldd &> /dev/null; then
        print_status "INFO" "Checking dynamic dependencies..."
        local deps=$(ldd "$bootstrap_path" 2>/dev/null || echo "not a dynamic executable")
        if echo "$deps" | grep -q "not a dynamic executable\|statically linked"; then
            print_status "SUCCESS" "Binary is statically linked (good for Lambda)"
        else
            print_status "WARNING" "Binary has dynamic dependencies:"
            echo "$deps"
        fi
    fi
    
    # Check binary size (Lambda has size limits)
    local file_size=$(stat -f%z "$bootstrap_path" 2>/dev/null || stat -c%s "$bootstrap_path" 2>/dev/null || echo "0")
    local size_mb=$((file_size / 1024 / 1024))
    
    if [[ $size_mb -lt 50 ]]; then
        print_status "SUCCESS" "Binary size (${size_mb}MB) is within Lambda limits"
    elif [[ $size_mb -lt 250 ]]; then
        print_status "WARNING" "Binary size (${size_mb}MB) is large but acceptable"
    else
        print_status "ERROR" "Binary size (${size_mb}MB) exceeds Lambda limits"
    fi
}

# Function to test all Lambda functions
test_all_lambda_functions() {
    local functions=("create-url" "redirect" "analytics")
    local build_errors=0
    
    print_status "INFO" "Testing all Lambda function builds..."
    
    for function in "${functions[@]}"; do
        echo
        print_status "INFO" "Processing Lambda function: $function"
        
        if build_lambda_function "$function"; then
            test_lambda_runtime "$function"
        else
            ((build_errors++))
        fi
    done
    
    return $build_errors
}

# Function to test workspace build
test_workspace_build() {
    print_status "INFO" "Testing workspace build with cargo-lambda..."
    
    local log_file="build-workspace.log"
    
    if cargo lambda build --release --target x86_64-unknown-linux-musl > "$log_file" 2>&1; then
        print_status "SUCCESS" "Workspace build completed"
        
        # Verify all expected artifacts
        local functions=("create-url" "redirect" "analytics")
        local missing_artifacts=0
        
        for function in "${functions[@]}"; do
            local bootstrap_path="target/lambda/$function/bootstrap"
            if [[ -f "$bootstrap_path" ]]; then
                print_status "SUCCESS" "$function bootstrap found"
            else
                print_status "ERROR" "$function bootstrap missing"
                ((missing_artifacts++))
            fi
        done
        
        if [[ $missing_artifacts -eq 0 ]]; then
            print_status "SUCCESS" "All Lambda artifacts created"
            
            # Create deployment packages for all
            print_status "INFO" "Creating deployment packages..."
            for function in "${functions[@]}"; do
                local bootstrap_path="target/lambda/$function/bootstrap"
                local zip_path="target/lambda/$function/bootstrap.zip"
                
                if zip -j "$zip_path" "$bootstrap_path" > "zip-workspace-${function}.log" 2>&1; then
                    print_status "SUCCESS" "$function deployment package created"
                else
                    print_status "ERROR" "Failed to create $function deployment package"
                    ((missing_artifacts++))
                fi
            done
        fi
        
        return $missing_artifacts
    else
        print_status "ERROR" "Workspace build failed"
        cat "$log_file"
        return 1
    fi
}

# Function to validate deployment packages
validate_deployment_packages() {
    print_status "INFO" "Validating deployment packages..."
    
    local functions=("create-url" "redirect" "analytics")
    local validation_errors=0
    
    for function in "${functions[@]}"; do
        local zip_path="target/lambda/$function/bootstrap.zip"
        
        if [[ -f "$zip_path" ]]; then
            print_status "INFO" "Validating $function deployment package"
            
            # Test zip integrity
            if zip -t "$zip_path" &> /dev/null; then
                print_status "SUCCESS" "$function zip is valid"
                
                # Check zip contents
                local contents=$(zip -l "$zip_path" 2>/dev/null | grep -v "Archive:" | grep -v "Length" | grep -v "^\-\-\-" | grep -v "^$" | tail -n +2 || echo "")
                if echo "$contents" | grep -q "bootstrap"; then
                    print_status "SUCCESS" "$function zip contains bootstrap file"
                else
                    print_status "ERROR" "$function zip missing bootstrap file"
                    ((validation_errors++))
                fi
                
                # Check file size for AWS Lambda limits
                local zip_size=$(stat -f%z "$zip_path" 2>/dev/null || stat -c%s "$zip_path" 2>/dev/null || echo "0")
                local size_mb=$((zip_size / 1024 / 1024))
                
                if [[ $size_mb -lt 50 ]]; then
                    print_status "SUCCESS" "$function package size (${size_mb}MB) is acceptable"
                elif [[ $size_mb -lt 250 ]]; then
                    print_status "WARNING" "$function package size (${size_mb}MB) is large"
                else
                    print_status "ERROR" "$function package size (${size_mb}MB) exceeds 250MB limit"
                    ((validation_errors++))
                fi
            else
                print_status "ERROR" "$function zip is corrupted"
                ((validation_errors++))
            fi
        else
            print_status "ERROR" "$function deployment package not found"
            ((validation_errors++))
        fi
    done
    
    return $validation_errors
}

# Function to generate build report
generate_build_report() {
    local report_file="lambda-build-report.md"
    
    print_status "INFO" "Generating build report..."
    
    cat > "$report_file" << EOF
# Lambda Build Test Report

Generated on: $(date)

## Environment
- cargo-lambda version: $(cargo lambda --version 2>/dev/null || echo "Not installed")
- Rust version: $(rustc --version)
- Target: x86_64-unknown-linux-musl

## Build Results

### Individual Function Builds
EOF

    # Add build results for each function
    local functions=("create-url" "redirect" "analytics")
    
    for function in "${functions[@]}"; do
        local bootstrap_path="target/lambda/$function/bootstrap"
        local zip_path="target/lambda/$function/bootstrap.zip"
        
        echo "#### $function" >> "$report_file"
        
        if [[ -f "$bootstrap_path" ]]; then
            local file_size=$(stat -f%z "$bootstrap_path" 2>/dev/null || stat -c%s "$bootstrap_path" 2>/dev/null || echo "unknown")
            echo "- Bootstrap binary: ✅ BUILT (${file_size} bytes)" >> "$report_file"
        else
            echo "- Bootstrap binary: ❌ MISSING" >> "$report_file"
        fi
        
        if [[ -f "$zip_path" ]]; then
            local zip_size=$(stat -f%z "$zip_path" 2>/dev/null || stat -c%s "$zip_path" 2>/dev/null || echo "unknown")
            echo "- Deployment package: ✅ CREATED (${zip_size} bytes)" >> "$report_file"
        else
            echo "- Deployment package: ❌ MISSING" >> "$report_file"
        fi
        
        echo "" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

### Build Artifacts Location
- Bootstrap binaries: \`target/lambda/{function}/bootstrap\`
- Deployment packages: \`target/lambda/{function}/bootstrap.zip\`

### Log Files
EOF

    # Add log files to report
    for log_file in *.log; do
        if [[ -f "$log_file" ]]; then
            echo "- \`$log_file\`" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

## Deployment Commands

To deploy these packages:

\`\`\`bash
# Deploy dev environment
just deploy-dev

# Or manually upload to Lambda
aws lambda update-function-code \\
    --function-name squrl-create-url-dev \\
    --zip-file fileb://target/lambda/create-url/bootstrap.zip
\`\`\`
EOF
    
    print_status "SUCCESS" "Build report generated: $report_file"
}

# Main function
main() {
    echo "🚀 Lambda Build Testing"
    echo "======================="
    echo
    
    local script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    local project_root=$(dirname "$script_dir")
    
    # Change to project root
    cd "$project_root"
    
    # Create logs directory
    mkdir -p logs/lambda-builds
    cd logs/lambda-builds
    
    # Check prerequisites
    if ! check_prerequisites; then
        print_status "ERROR" "Prerequisites check failed"
        exit 1
    fi
    
    echo
    
    # Clean previous builds
    cd "$project_root"
    clean_build_artifacts
    cd logs/lambda-builds
    
    echo
    
    local build_errors=0
    
    # Test workspace build (builds all functions at once)
    print_status "INFO" "Testing workspace build..."
    if ! test_workspace_build; then
        ((build_errors += $?))
    fi
    
    echo
    
    # Test individual function builds (more detailed testing)
    print_status "INFO" "Testing individual function builds..."
    if ! test_all_lambda_functions; then
        ((build_errors += $?))
    fi
    
    echo
    
    # Validate deployment packages
    print_status "INFO" "Validating deployment packages..."
    if ! validate_deployment_packages; then
        ((build_errors += $?))
    fi
    
    echo
    
    # Generate report
    generate_build_report
    
    echo
    
    # Summary
    echo "📋 Lambda Build Summary"
    echo "----------------------"
    if [[ $build_errors -eq 0 ]]; then
        print_status "SUCCESS" "All Lambda builds completed successfully!"
        echo
        print_status "INFO" "Build artifacts:"
        echo "  - Bootstrap binaries: target/lambda/{function}/bootstrap"
        echo "  - Deployment packages: target/lambda/{function}/bootstrap.zip"
        echo
        print_status "INFO" "Next steps:"
        echo "  1. Review the build report: logs/lambda-builds/lambda-build-report.md"
        echo "  2. Run integration tests: scripts/integration-tests.sh"
        echo "  3. Deploy to dev environment: just deploy-dev"
    else
        print_status "ERROR" "Found $build_errors build error(s)"
        echo
        print_status "INFO" "Check the log files for details and fix the issues"
        exit 1
    fi
}

main "$@"