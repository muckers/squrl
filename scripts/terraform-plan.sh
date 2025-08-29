#!/bin/bash

# Terraform Planning Script
# Creates terraform plans for dev and prod environments
# Validates dependencies and checks for deployment issues

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

# Function to create and validate terraform plan
create_terraform_plan() {
    local environment=$1
    local script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    local project_root=$(dirname "$script_dir")
    local env_dir="$project_root/terraform/environments/$environment"
    
    if [[ ! -d "$env_dir" ]]; then
        print_status "ERROR" "Environment directory not found: $env_dir"
        return 1
    fi
    
    print_status "INFO" "Creating Terraform plan for $environment environment"
    
    pushd "$env_dir" > /dev/null
    
    # Initialize Terraform
    print_status "INFO" "Initializing Terraform for $environment..."
    if ! terraform init > /dev/null 2>&1; then
        print_status "ERROR" "Failed to initialize Terraform for $environment"
        # Try without backend for validation purposes
        print_status "INFO" "Trying initialization without backend..."
        if ! terraform init -backend=false > /dev/null 2>&1; then
            print_status "ERROR" "Failed to initialize Terraform even without backend"
            popd > /dev/null
            return 1
        fi
        print_status "WARNING" "Initialized without backend - plan may not reflect current state"
    fi
    
    # Check for required variables
    local required_vars_missing=0
    
    if [[ ! -f "terraform.tfvars" ]]; then
        print_status "WARNING" "No terraform.tfvars file found for $environment"
        print_status "INFO" "Using default variable values"
    fi
    
    # Create the plan
    local plan_file="${environment}-tfplan-$(date +%Y%m%d-%H%M%S)"
    
    print_status "INFO" "Creating plan: $plan_file"
    
    if terraform plan -out="$plan_file" > "${plan_file}.log" 2>&1; then
        print_status "SUCCESS" "Terraform plan created successfully for $environment"
        
        # Analyze the plan
        print_status "INFO" "Analyzing plan for $environment..."
        
        # Count resources to be created/modified/destroyed
        local to_add=$(terraform show "$plan_file" | grep -c "# .* will be created" || echo "0")
        local to_change=$(terraform show "$plan_file" | grep -c "# .* will be updated" || echo "0") 
        local to_destroy=$(terraform show "$plan_file" | grep -c "# .* will be destroyed" || echo "0")
        
        echo "  Resources to add: $to_add"
        echo "  Resources to change: $to_change"
        echo "  Resources to destroy: $to_destroy"
        
        # Check for potential issues
        if terraform show "$plan_file" | grep -q "Error:"; then
            print_status "WARNING" "Potential errors detected in plan"
        fi
        
        if terraform show "$plan_file" | grep -qi "force.*replacement"; then
            print_status "WARNING" "Plan includes resource replacements (destructive changes)"
        fi
        
        # Check for security-related resources
        local security_resources=$(terraform show "$plan_file" | grep -c "aws_kms_key\|aws_secretsmanager_secret\|aws_wafv2_web_acl\|aws_security_group" || echo "0")
        if [[ $security_resources -gt 0 ]]; then
            print_status "INFO" "Security resources in plan: $security_resources"
        fi
        
        # Save plan details
        echo "# Terraform Plan Analysis for $environment Environment" > "${plan_file}-summary.md"
        echo "Generated on: $(date)" >> "${plan_file}-summary.md"
        echo "" >> "${plan_file}-summary.md"
        echo "## Resource Changes" >> "${plan_file}-summary.md"
        echo "- Resources to add: $to_add" >> "${plan_file}-summary.md"
        echo "- Resources to change: $to_change" >> "${plan_file}-summary.md"
        echo "- Resources to destroy: $to_destroy" >> "${plan_file}-summary.md"
        echo "" >> "${plan_file}-summary.md"
        echo "## Plan File" >> "${plan_file}-summary.md"
        echo "- Plan file: \`$plan_file\`" >> "${plan_file}-summary.md"
        echo "- Log file: \`${plan_file}.log\`" >> "${plan_file}-summary.md"
        echo "" >> "${plan_file}-summary.md"
        echo "## Commands to Apply" >> "${plan_file}-summary.md"
        echo "\`\`\`bash" >> "${plan_file}-summary.md"
        echo "cd $env_dir" >> "${plan_file}-summary.md"
        echo "terraform apply \"$plan_file\"" >> "${plan_file}-summary.md"
        echo "\`\`\`" >> "${plan_file}-summary.md"
        
        print_status "SUCCESS" "Plan analysis saved to ${plan_file}-summary.md"
        
    else
        print_status "ERROR" "Failed to create Terraform plan for $environment"
        print_status "INFO" "Check the log file: ${plan_file}.log"
        cat "${plan_file}.log"
        popd > /dev/null
        return 1
    fi
    
    popd > /dev/null
}

# Function to validate prerequisites
check_prerequisites() {
    print_status "INFO" "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_status "ERROR" "Terraform is not installed"
        return 1
    fi
    
    # Check terraform version
    local tf_version=$(terraform version | head -n1)
    print_status "SUCCESS" "Found $tf_version"
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        print_status "WARNING" "AWS CLI is not installed - some features may not work"
    else
        local aws_version=$(aws --version)
        print_status "SUCCESS" "Found $aws_version"
    fi
    
    # Check if build artifacts exist
    local project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)
    if [[ ! -d "$project_root/target/lambda" ]]; then
        print_status "WARNING" "Lambda build artifacts not found"
        print_status "INFO" "Run 'just build' to create Lambda deployment packages"
    else
        print_status "SUCCESS" "Lambda build artifacts found"
    fi
}

# Main function
main() {
    local environment=${1:-""}
    
    echo "🏗️  Terraform Planning and Validation"
    echo "===================================="
    echo
    
    if [[ -z "$environment" ]]; then
        print_status "INFO" "Usage: $0 [dev|prod|all]"
        print_status "INFO" "No environment specified, planning all environments"
        environment="all"
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        print_status "ERROR" "Prerequisites check failed"
        exit 1
    fi
    
    echo
    
    local planning_errors=0
    
    case $environment in
        "dev")
            print_status "INFO" "Planning dev environment only"
            if ! create_terraform_plan "dev"; then
                ((planning_errors++))
            fi
            ;;
        "prod")
            print_status "INFO" "Planning prod environment only"
            if ! create_terraform_plan "prod"; then
                ((planning_errors++))
            fi
            ;;
        "all"|*)
            print_status "INFO" "Planning all environments"
            
            echo
            echo "🛠️  Development Environment"
            echo "--------------------------"
            if ! create_terraform_plan "dev"; then
                ((planning_errors++))
            fi
            
            echo
            echo "🏭 Production Environment"
            echo "------------------------"
            if ! create_terraform_plan "prod"; then
                ((planning_errors++))
            fi
            ;;
    esac
    
    echo
    
    # Summary
    echo "📋 Planning Summary"
    echo "------------------"
    if [[ $planning_errors -eq 0 ]]; then
        print_status "SUCCESS" "All Terraform plans created successfully!"
        echo
        print_status "INFO" "Next steps:"
        echo "  1. Review the plan files and summaries"
        echo "  2. Check for any warnings or destructive changes"
        echo "  3. Apply plans when ready: terraform apply <plan-file>"
        echo "  4. Run security validation: scripts/security-validation.sh"
    else
        print_status "ERROR" "Found $planning_errors planning error(s)"
        echo
        print_status "INFO" "Fix the errors above before proceeding with deployment"
        exit 1
    fi
}

main "$@"