#!/bin/bash

# Terraform Validation Script
# Validates all Terraform modules and environments for syntax and dependencies

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

# Function to validate a single Terraform directory
validate_terraform_directory() {
    local dir=$1
    local name=$(basename "$dir")
    
    print_status "INFO" "Validating Terraform configuration: $name"
    
    pushd "$dir" > /dev/null
    
    # Initialize Terraform (skip backend initialization for modules)
    if [[ "$dir" == *"/modules/"* ]]; then
        terraform init -backend=false > /dev/null 2>&1
    else
        # For environments, use backend configuration
        if ! terraform init > /dev/null 2>&1; then
            print_status "WARNING" "Failed to initialize backend for $name, trying without backend"
            terraform init -backend=false > /dev/null 2>&1
        fi
    fi
    
    # Validate syntax
    if terraform validate > /dev/null 2>&1; then
        print_status "SUCCESS" "$name: Terraform syntax valid"
    else
        print_status "ERROR" "$name: Terraform validation failed"
        terraform validate
        popd > /dev/null
        return 1
    fi
    
    # Format check
    if terraform fmt -check > /dev/null 2>&1; then
        print_status "SUCCESS" "$name: Terraform formatting correct"
    else
        print_status "WARNING" "$name: Terraform formatting issues found"
        echo "  Run 'terraform fmt' in $dir to fix formatting"
    fi
    
    popd > /dev/null
}

# Main validation function
main() {
    echo "🔍 Terraform Configuration Validation"
    echo "======================================"
    echo
    
    local script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    local project_root=$(dirname "$script_dir")
    local terraform_dir="$project_root/terraform"
    
    if [[ ! -d "$terraform_dir" ]]; then
        print_status "ERROR" "Terraform directory not found: $terraform_dir"
        exit 1
    fi
    
    local validation_errors=0
    
    print_status "INFO" "Starting validation of Terraform modules and environments"
    echo
    
    # Validate all modules
    echo "📦 Validating Terraform Modules"
    echo "-------------------------------"
    if [[ -d "$terraform_dir/modules" ]]; then
        for module_dir in "$terraform_dir/modules"/*; do
            if [[ -d "$module_dir" && -f "$module_dir/main.tf" ]]; then
                if ! validate_terraform_directory "$module_dir"; then
                    ((validation_errors++))
                fi
            fi
        done
    else
        print_status "WARNING" "No modules directory found"
    fi
    
    echo
    
    # Validate environments
    echo "🌍 Validating Terraform Environments"
    echo "-----------------------------------"
    if [[ -d "$terraform_dir/environments" ]]; then
        for env_dir in "$terraform_dir/environments"/*; do
            if [[ -d "$env_dir" && -f "$env_dir/main.tf" ]]; then
                if ! validate_terraform_directory "$env_dir"; then
                    ((validation_errors++))
                fi
            fi
        done
    else
        print_status "WARNING" "No environments directory found"
    fi
    
    echo
    
    # Summary
    echo "📋 Validation Summary"
    echo "-------------------"
    if [[ $validation_errors -eq 0 ]]; then
        print_status "SUCCESS" "All Terraform configurations are valid!"
        echo
        print_status "INFO" "Next steps:"
        echo "  1. Run 'just terraform-plan-dev' to test dev environment planning"
        echo "  2. Run 'just terraform-plan-prod' to test prod environment planning" 
        echo "  3. Check the validation checklist in docs/security-validation-checklist.md"
    else
        print_status "ERROR" "Found $validation_errors validation error(s)"
        echo
        print_status "INFO" "Fix the errors above before proceeding with deployment"
        exit 1
    fi
}

main "$@"