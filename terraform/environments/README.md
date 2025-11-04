# Terraform Environment Configuration

This directory contains environment-specific Terraform configurations for squrl.

## Configuration Pattern

We use a **required** two-file pattern to separate safe defaults from sensitive values:

```
terraform.tfvars              ← Tracked in git (safe defaults only)
secrets.auto.tfvars          ← Local only, REQUIRED, gitignored (your actual secrets)
secrets.auto.tfvars.example  ← Tracked template
```

⚠️ **IMPORTANT**: Terraform will **FAIL** if `secrets.auto.tfvars` is missing. This is intentional!

### How It Works

1. **`terraform.tfvars`** - Checked into git
   - Contains only safe, non-sensitive defaults
   - Region, environment name, public email addresses
   - Safe for open-source repository

2. **`secrets.auto.tfvars`** - Local only (gitignored)
   - Contains your actual AWS resource ARNs and secrets
   - **Never committed to git**
   - Terraform automatically loads all `*.auto.tfvars` files
   - Values here override `terraform.tfvars`

3. **`secrets.auto.tfvars.example`** - Tracked template
   - Shows what values you need to provide
   - Copy to `secrets.auto.tfvars` and fill in your values

## Initial Setup

For each environment (dev/prod):

```bash
cd terraform/environments/prod  # or dev

# 1. Copy the example file
cp secrets.auto.tfvars.example secrets.auto.tfvars

# 2. Edit with your actual values
vim secrets.auto.tfvars

# 3. Add your ACM certificate ARN
# Get from: AWS Console → Certificate Manager → Certificates
acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abc-123-def"

# 4. Run terraform
terraform init
terraform plan
terraform apply
```

## Getting AWS Resource Values

### ACM Certificate ARN

The ACM certificate **must** be created in `us-east-1` region (CloudFront requirement):

```bash
# Create certificate in AWS Console or via CLI
aws acm request-certificate \
  --domain-name squrl.pub \
  --validation-method DNS \
  --region us-east-1

# Get the ARN
aws acm list-certificates --region us-east-1

# Copy the ARN to secrets.auto.tfvars
```

### After Terraform Apply

Some values are only available after deployment:

```bash
# Get CloudFront distribution ID
terraform output cloudfront_distribution_id

# Get API Gateway URL
terraform output api_gateway_url

# Add these to your .env file (not in Terraform)
```

## Security Notes

✅ **DO:**
- Keep `secrets.auto.tfvars` local only
- Use different values for dev/staging/prod
- Rotate credentials regularly
- Use least-privilege IAM permissions

❌ **DON'T:**
- Never commit `secrets.auto.tfvars` to git
- Don't share your secrets file
- Don't use production secrets in dev

## File Precedence

Terraform loads variables in this order (later overrides earlier):

1. Environment variables (`TF_VAR_*`)
2. `terraform.tfvars`
3. `*.auto.tfvars` (alphabetically)
4. `-var` and `-var-file` command line flags

So your `secrets.auto.tfvars` will override defaults in `terraform.tfvars`.

## Troubleshooting

### Error: "No value for required variable"

```
Error: No value for required variable
  on variables.tf line 18:
  18: variable "acm_certificate_arn" {
```

**This means `secrets.auto.tfvars` is missing or incomplete.**

Fix:
```bash
# Check if file exists
ls secrets.auto.tfvars

# If missing, copy from example
cp secrets.auto.tfvars.example secrets.auto.tfvars

# Edit and add your actual ACM certificate ARN
vim secrets.auto.tfvars
```

### "Invalid ARN" error

Check that your ACM certificate:
- Is in `us-east-1` region (required for CloudFront)
- Is validated (DNS or email validation complete)
- ARN format: `arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID`

### Want to see what values Terraform is using?

```bash
# Show all variable values (be careful, shows secrets!)
terraform console
> var.acm_certificate_arn
```

## Adding New Secrets

To add a new sensitive variable:

1. Add to `variables.tf`:
   ```hcl
   variable "new_secret" {
     description = "Description"
     type        = string
     sensitive   = true
   }
   ```

2. Add to `secrets.auto.tfvars.example`:
   ```hcl
   new_secret = "example-value"
   ```

3. Add to your local `secrets.auto.tfvars`:
   ```hcl
   new_secret = "actual-secret-value"
   ```

## Migration from Old Pattern

If you're migrating from the old pattern where secrets were in `terraform.tfvars`:

```bash
# 1. Copy your current terraform.tfvars
cp terraform.tfvars terraform.tfvars.backup

# 2. Create secrets.auto.tfvars with sensitive values
cp secrets.auto.tfvars.example secrets.auto.tfvars
# Edit and add your actual ARN

# 3. Update terraform.tfvars to remove sensitive values
# (We've already done this in the latest version)

# 4. Test that it works
terraform plan
```
