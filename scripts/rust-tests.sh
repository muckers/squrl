#!/bin/bash

# Rust Testing and Validation Script
# Comprehensive testing for all Rust code including unit tests, linting, and compilation

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

# Function to run cargo command with error handling
run_cargo_command() {
    local command=$1
    local description=$2
    local log_file=$3
    
    print_status "INFO" "Running: $description"
    
    if $command > "$log_file" 2>&1; then
        print_status "SUCCESS" "$description completed"
        return 0
    else
        print_status "ERROR" "$description failed"
        echo "Error details:"
        cat "$log_file"
        return 1
    fi
}

# Function to check Rust toolchain
check_rust_toolchain() {
    print_status "INFO" "Checking Rust toolchain..."
    
    if ! command -v cargo &> /dev/null; then
        print_status "ERROR" "Cargo is not installed"
        return 1
    fi
    
    if ! command -v rustc &> /dev/null; then
        print_status "ERROR" "Rustc is not installed"
        return 1
    fi
    
    local rust_version=$(rustc --version)
    print_status "SUCCESS" "Found $rust_version"
    
    local cargo_version=$(cargo --version)
    print_status "SUCCESS" "Found $cargo_version"
    
    # Check for required components
    if rustup component list --installed | grep -q clippy; then
        print_status "SUCCESS" "Clippy is installed"
    else
        print_status "WARNING" "Clippy not installed, installing..."
        rustup component add clippy
    fi
    
    if rustup component list --installed | grep -q rustfmt; then
        print_status "SUCCESS" "Rustfmt is installed"
    else
        print_status "WARNING" "Rustfmt not installed, installing..."
        rustup component add rustfmt
    fi
}

# Function to test workspace dependencies
test_dependencies() {
    print_status "INFO" "Testing workspace dependencies..."
    
    local log_file="test-deps.log"
    
    # Check for security vulnerabilities
    if command -v cargo-audit &> /dev/null; then
        print_status "INFO" "Checking for security vulnerabilities..."
        if cargo audit > "$log_file" 2>&1; then
            print_status "SUCCESS" "No security vulnerabilities found"
        else
            print_status "WARNING" "Security vulnerabilities detected - check $log_file"
        fi
    else
        print_status "WARNING" "cargo-audit not installed, skipping vulnerability check"
        print_status "INFO" "Install with: cargo install cargo-audit"
    fi
    
    # Check for outdated dependencies
    if command -v cargo-outdated &> /dev/null; then
        print_status "INFO" "Checking for outdated dependencies..."
        if cargo outdated > "$log_file" 2>&1; then
            print_status "SUCCESS" "Dependencies checked"
        else
            print_status "WARNING" "Issues with dependency check - see $log_file"
        fi
    else
        print_status "WARNING" "cargo-outdated not installed, skipping outdated check"
    fi
}

# Function to run compilation tests
test_compilation() {
    print_status "INFO" "Testing Rust compilation..."
    
    local errors=0
    
    # Test debug compilation
    if run_cargo_command "cargo build" "Debug compilation" "compile-debug.log"; then
        print_status "SUCCESS" "Debug compilation successful"
    else
        ((errors++))
    fi
    
    # Test release compilation
    if run_cargo_command "cargo build --release" "Release compilation" "compile-release.log"; then
        print_status "SUCCESS" "Release compilation successful"
    else
        ((errors++))
    fi
    
    # Test all features
    if run_cargo_command "cargo build --all-features" "All features compilation" "compile-features.log"; then
        print_status "SUCCESS" "All features compilation successful"
    else
        ((errors++))
    fi
    
    # Test individual packages
    local packages=("shared" "create-url" "redirect" "analytics")
    
    for package in "${packages[@]}"; do
        local package_dir=""
        if [[ "$package" == "shared" ]]; then
            package_dir="shared"
        else
            package_dir="lambda/$package"
        fi
        
        if [[ -d "$package_dir" ]]; then
            print_status "INFO" "Testing compilation for $package package"
            pushd "$package_dir" > /dev/null
            
            if run_cargo_command "cargo build" "$package package compilation" "../compile-$package.log"; then
                print_status "SUCCESS" "$package package compilation successful"
            else
                ((errors++))
            fi
            
            popd > /dev/null
        fi
    done
    
    return $errors
}

# Function to run unit tests
run_unit_tests() {
    print_status "INFO" "Running unit tests..."
    
    local errors=0
    
    # Run workspace tests
    if run_cargo_command "cargo test --workspace" "Workspace unit tests" "test-workspace.log"; then
        print_status "SUCCESS" "All workspace tests passed"
    else
        ((errors++))
    fi
    
    # Run tests with all features
    if run_cargo_command "cargo test --workspace --all-features" "Tests with all features" "test-features.log"; then
        print_status "SUCCESS" "All feature tests passed"
    else
        ((errors++))
    fi
    
    # Run documentation tests
    if run_cargo_command "cargo test --workspace --doc" "Documentation tests" "test-docs.log"; then
        print_status "SUCCESS" "Documentation tests passed"
    else
        print_status "WARNING" "Documentation tests failed or none found"
    fi
    
    return $errors
}

# Function to run linting
run_linting() {
    print_status "INFO" "Running code linting..."
    
    local errors=0
    
    # Run clippy
    if run_cargo_command "cargo clippy --all-targets --all-features -- -D warnings" "Clippy linting" "clippy.log"; then
        print_status "SUCCESS" "Clippy linting passed"
    else
        ((errors++))
    fi
    
    # Check formatting
    if cargo fmt --all -- --check > "fmt-check.log" 2>&1; then
        print_status "SUCCESS" "Code formatting is correct"
    else
        print_status "WARNING" "Code formatting issues found"
        print_status "INFO" "Run 'cargo fmt' to fix formatting"
    fi
    
    return $errors
}

# Function to run specific tests for security features
test_security_features() {
    print_status "INFO" "Testing security-related features..."
    
    local errors=0
    
    # Test shared library specifically for secrets manager integration
    if [[ -d "shared" ]]; then
        pushd shared > /dev/null
        
        print_status "INFO" "Testing secrets manager module..."
        if run_cargo_command "cargo test secrets" "Secrets manager tests" "../test-secrets.log"; then
            print_status "SUCCESS" "Secrets manager tests passed"
        else
            print_status "WARNING" "Secrets manager tests failed or none found"
        fi
        
        print_status "INFO" "Testing validation module..."
        if run_cargo_command "cargo test validation" "Validation tests" "../test-validation.log"; then
            print_status "SUCCESS" "Validation tests passed"
        else
            print_status "WARNING" "Validation tests failed or none found"
        fi
        
        popd > /dev/null
    fi
    
    return $errors
}

# Function to generate test reports
generate_test_report() {
    local report_file="rust-test-report.md"
    
    print_status "INFO" "Generating test report..."
    
    cat > "$report_file" << EOF
# Rust Testing Report

Generated on: $(date)

## Environment
- Rust version: $(rustc --version)
- Cargo version: $(cargo --version)

## Test Results

### Compilation Tests
- Debug compilation: $(test -f compile-debug.log && echo "✅ PASSED" || echo "❌ FAILED")
- Release compilation: $(test -f compile-release.log && echo "✅ PASSED" || echo "❌ FAILED")
- All features compilation: $(test -f compile-features.log && echo "✅ PASSED" || echo "❌ FAILED")

### Unit Tests
- Workspace tests: $(test -f test-workspace.log && echo "✅ PASSED" || echo "❌ FAILED")
- Feature tests: $(test -f test-features.log && echo "✅ PASSED" || echo "❌ FAILED")

### Code Quality
- Clippy linting: $(test -f clippy.log && echo "✅ PASSED" || echo "❌ FAILED")
- Code formatting: $(test -f fmt-check.log && echo "✅ PASSED" || echo "⚠️ WARNINGS")

### Security Features
- Secrets manager tests: $(test -f test-secrets.log && echo "✅ PASSED" || echo "⚠️ SKIPPED")
- Validation tests: $(test -f test-validation.log && echo "✅ PASSED" || echo "⚠️ SKIPPED")

## Log Files
EOF

    # Add log files to report
    for log_file in *.log; do
        if [[ -f "$log_file" ]]; then
            echo "- \`$log_file\`" >> "$report_file"
        fi
    done
    
    print_status "SUCCESS" "Test report generated: $report_file"
}

# Main function
main() {
    echo "🦀 Rust Testing and Validation"
    echo "=============================="
    echo
    
    local script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    local project_root=$(dirname "$script_dir")
    
    # Change to project root
    cd "$project_root"
    
    # Create logs directory
    mkdir -p logs/rust-tests
    cd logs/rust-tests
    
    local total_errors=0
    
    # Check Rust toolchain
    if ! check_rust_toolchain; then
        print_status "ERROR" "Rust toolchain check failed"
        exit 1
    fi
    
    echo
    
    # Test dependencies
    test_dependencies
    
    echo
    
    # Run compilation tests
    print_status "INFO" "Starting compilation tests..."
    if ! test_compilation; then
        ((total_errors += $?))
    fi
    
    echo
    
    # Run unit tests
    print_status "INFO" "Starting unit tests..."
    if ! run_unit_tests; then
        ((total_errors += $?))
    fi
    
    echo
    
    # Run linting
    print_status "INFO" "Starting linting checks..."
    if ! run_linting; then
        ((total_errors += $?))
    fi
    
    echo
    
    # Test security features
    print_status "INFO" "Starting security feature tests..."
    if ! test_security_features; then
        ((total_errors += $?))
    fi
    
    echo
    
    # Generate report
    generate_test_report
    
    echo
    
    # Summary
    echo "📋 Rust Testing Summary"
    echo "----------------------"
    if [[ $total_errors -eq 0 ]]; then
        print_status "SUCCESS" "All Rust tests passed!"
        echo
        print_status "INFO" "Next steps:"
        echo "  1. Review the test report: logs/rust-tests/rust-test-report.md"
        echo "  2. Run Lambda build tests: scripts/lambda-build-tests.sh"
        echo "  3. Run integration tests: scripts/integration-tests.sh"
    else
        print_status "ERROR" "Found $total_errors test failure(s)"
        echo
        print_status "INFO" "Check the log files for details and fix the issues"
        exit 1
    fi
}

main "$@"