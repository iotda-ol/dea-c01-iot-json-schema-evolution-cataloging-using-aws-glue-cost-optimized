# Deployment Guide

## Prerequisites

### Required Tools
- **Terraform** >= 1.0 ([Install](https://www.terraform.io/downloads))
- **AWS CLI** >= 2.0 ([Install](https://aws.amazon.com/cli/))
- **Python** >= 3.8 ([Install](https://www.python.org/downloads/))
- **Git** ([Install](https://git-scm.com/downloads))

### AWS Requirements
- AWS Account with appropriate permissions
- IAM user or role with permissions for:
  - S3 (create buckets, manage lifecycle)
  - Glue (create databases, tables, schemas, registries)
  - IAM (create roles and policies)
  - Athena (query execution)

## Step 1: Clone Repository

```bash
git clone https://github.com/iotda-ol/dea-c01-iot-json-schema-evolution-cataloging-using-aws-glue-cost-optimized.git
cd dea-c01-iot-json-schema-evolution-cataloging-using-aws-glue-cost-optimized
```

## Step 2: Configure AWS Credentials

### Option A: AWS CLI Configuration
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region (e.g., us-east-1)
# Enter default output format (json)
```

### Option B: Environment Variables
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Verify Configuration
```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

## Step 3: Deploy Infrastructure with Terraform

### Initialize Terraform
```bash
cd terraform
terraform init
```

### Review Deployment Plan
```bash
terraform plan
```

### Customize Variables (Optional)
Create a `terraform.tfvars` file:

```hcl
aws_region   = "us-east-1"
environment  = "dev"
project_name = "iot-catalog"
```

### Deploy Resources
```bash
terraform apply
```

Type `yes` when prompted to confirm deployment.

### Deployment Time
- Expected duration: 2-3 minutes
- Resources created:
  - 1 S3 bucket
  - 1 Glue database
  - 1 Glue table
  - 1 Glue schema registry
  - 1 Glue schema
  - 1 IAM role
  - 1 IAM policy

### Capture Outputs
```bash
terraform output
```

Save the outputs for later use:
```
s3_bucket_name = "iot-catalog-iot-data-dev-123456789012"
glue_database_name = "iot_catalog_iot_catalog_dev"
schema_registry_name = "iot-catalog-iot-schema-registry-dev"
analytics_role_arn = "arn:aws:iam::123456789012:role/iot-catalog-analytics-read-dev"
```

## Step 4: Set Up Python Environment

### Install Python Dependencies
```bash
cd ../src/python
pip install -r requirements.txt
```

Or using virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## Step 5: Generate Sample IoT Data

### Generate Data for 1 Day (Schema v1)
```bash
python iot_data_generator.py \
  --bucket <S3_BUCKET_NAME> \
  --registry <SCHEMA_REGISTRY_NAME> \
  --devices 5 \
  --readings 100 \
  --days 1 \
  --schema-version 1
```

Replace `<S3_BUCKET_NAME>` and `<SCHEMA_REGISTRY_NAME>` with values from Terraform outputs.

### Generate Data for 7 Days (Schema v2 - Evolution)
```bash
python iot_data_generator.py \
  --bucket <S3_BUCKET_NAME> \
  --registry <SCHEMA_REGISTRY_NAME> \
  --devices 10 \
  --readings 288 \
  --days 7 \
  --schema-version 2
```

### Verify Data Upload
```bash
aws s3 ls s3://<S3_BUCKET_NAME>/telemetry/ --recursive --human-readable
```

Expected output:
```
2024-12-16 10:30:45   12.3 KiB telemetry/year=2024/month=12/day=16/telemetry_20241216_103045.json.gz
```

## Step 6: Verify Glue Catalog

### Check Database
```bash
aws glue get-database --name <GLUE_DATABASE_NAME>
```

### Check Table
```bash
aws glue get-table \
  --database-name <GLUE_DATABASE_NAME> \
  --name iot_telemetry
```

### List Schema Versions
```bash
python schema_manager.py \
  --registry <SCHEMA_REGISTRY_NAME> \
  --action list-versions
```

## Step 7: Query Data with Athena

### Via AWS Console

1. Open AWS Athena Console
2. Select `<GLUE_DATABASE_NAME>` as database
3. Run sample query:

```sql
SELECT 
  deviceid,
  AVG(temperature) as avg_temp,
  AVG(humidity) as avg_humidity,
  COUNT(*) as reading_count
FROM iot_telemetry
WHERE year = 2024 AND month = 12
GROUP BY deviceid
ORDER BY avg_temp DESC
LIMIT 10;
```

### Via AWS CLI

```bash
# Start query execution
QUERY_ID=$(aws athena start-query-execution \
  --query-string "SELECT COUNT(*) as total_records FROM iot_telemetry WHERE year = 2024" \
  --query-execution-context Database=<GLUE_DATABASE_NAME> \
  --result-configuration OutputLocation=s3://aws-athena-query-results-<ACCOUNT_ID>-<REGION>/ \
  --query 'QueryExecutionId' \
  --output text)

# Check query status
aws athena get-query-execution --query-execution-id $QUERY_ID

# Get results
aws athena get-query-results --query-execution-id $QUERY_ID
```

## Step 8: Grant Access to Analytics Team

### Create IAM User for Analytics Team Member
```bash
aws iam create-user --user-name analytics-user-1
```

### Allow User to Assume Analytics Role
```bash
aws iam attach-user-policy \
  --user-name analytics-user-1 \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
```

### User Assumes Role
```bash
aws sts assume-role \
  --role-arn <ANALYTICS_ROLE_ARN> \
  --role-session-name analytics-session \
  --external-id analytics-team
```

## Step 9: Cost Monitoring Setup

### Create Cost Allocation Tags
```bash
# Tag resources for cost tracking
aws s3api put-bucket-tagging \
  --bucket <S3_BUCKET_NAME> \
  --tagging 'TagSet=[{Key=Project,Value=IoT-Data-Cataloging},{Key=CostCenter,Value=Analytics}]'
```

### Enable Cost Allocation Tags (AWS Console)
1. Go to AWS Billing Console
2. Navigate to Cost Allocation Tags
3. Activate tags: `Project`, `Environment`, `CostCenter`

### Set Up Budget Alert
```bash
aws budgets create-budget \
  --account-id <ACCOUNT_ID> \
  --budget file://budget-config.json
```

Create `budget-config.json`:
```json
{
  "BudgetName": "IoT-Catalog-Monthly-Budget",
  "BudgetLimit": {
    "Amount": "50",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

## Verification Checklist

- [ ] Terraform deployment successful
- [ ] S3 bucket created with lifecycle policies
- [ ] Glue database and table visible in console
- [ ] Schema registry contains schema versions
- [ ] Sample data uploaded to S3
- [ ] Athena queries return results
- [ ] Analytics role can be assumed
- [ ] Cost allocation tags active

## Troubleshooting

### Issue: Terraform Apply Fails

**Error:** `Error creating S3 bucket: BucketAlreadyExists`

**Solution:** Bucket names must be globally unique. Change `project_name` in `terraform.tfvars`:
```hcl
project_name = "iot-catalog-<YOUR_UNIQUE_ID>"
```

### Issue: Python Script Cannot Upload to S3

**Error:** `AccessDenied: Access Denied`

**Solution:** Verify AWS credentials and IAM permissions:
```bash
aws sts get-caller-identity
aws s3 ls s3://<BUCKET_NAME>/
```

### Issue: Athena Query Returns No Results

**Error:** Query succeeds but returns 0 rows

**Solution:** Check data exists and partitions are correct:
```bash
aws s3 ls s3://<BUCKET_NAME>/telemetry/year=2024/month=12/day=16/
```

### Issue: Schema Registration Fails

**Error:** `EntityNotFoundException: Registry not found`

**Solution:** Verify registry was created by Terraform:
```bash
aws glue list-registries
```

## Clean Up

### Remove Sample Data
```bash
aws s3 rm s3://<S3_BUCKET_NAME>/telemetry/ --recursive
```

### Destroy Infrastructure
```bash
cd terraform
terraform destroy
```

Type `yes` when prompted to confirm destruction.

**Note:** This will delete all resources including data. Backup important data before running.

## Next Steps

- Review [USAGE-EXAMPLES.md](USAGE-EXAMPLES.md) for common query patterns
- Read [DEA-C01-COST-OPTIMIZATION.md](DEA-C01-COST-OPTIMIZATION.md) for optimization tips
- Explore [ARCHITECTURE.md](ARCHITECTURE.md) for system design details

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review AWS CloudWatch Logs for detailed error messages
3. Open an issue in the GitHub repository
