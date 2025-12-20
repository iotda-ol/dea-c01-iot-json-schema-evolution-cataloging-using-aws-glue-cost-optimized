# Quick Start Guide

Get up and running with the cost-optimized IoT data cataloging solution in 5 minutes.

## 📋 Prerequisites

- AWS Account
- AWS CLI configured with credentials
- Terraform >= 1.0
- Python >= 3.8

## 🚀 5-Minute Setup

### Step 1: Clone and Configure (1 min)

```bash
git clone https://github.com/iotda-ol/dea-c01-iot-json-schema-evolution-cataloging-using-aws-glue-cost-optimized.git
cd dea-c01-iot-json-schema-evolution-cataloging-using-aws-glue-cost-optimized
```

### Step 2: Deploy Infrastructure (2 min)

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

**Save the outputs:**
```bash
terraform output > ../outputs.txt
```

### Step 3: Generate Sample Data (1 min)

```bash
cd ../src/python
pip install -r requirements.txt

# Replace <BUCKET> with your S3 bucket name from outputs
python iot_data_generator.py \
  --bucket <BUCKET_NAME> \
  --devices 5 \
  --readings 100 \
  --days 1
```

### Step 4: Query with Athena (1 min)

Open AWS Athena Console and run:

```sql
-- Replace database name with your Glue database name
SELECT 
    deviceid,
    AVG(temperature) as avg_temp,
    COUNT(*) as readings
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
GROUP BY deviceid;
```

## 🎉 Success!

You now have:
- ✅ Cost-optimized S3 storage with lifecycle policies
- ✅ AWS Glue Data Catalog with partitioned tables
- ✅ Schema Registry for version management
- ✅ Sample IoT data ready to query
- ✅ Serverless analytics with Athena

## 📚 Next Steps

1. **Explore More Queries:** See [docs/USAGE-EXAMPLES.md](docs/USAGE-EXAMPLES.md)
2. **Understand Architecture:** Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
3. **Learn Cost Optimization:** Check [docs/DEA-C01-COST-OPTIMIZATION.md](docs/DEA-C01-COST-OPTIMIZATION.md)
4. **Schema Evolution:** Generate v2 data with `--schema-version 2`

## 💰 Estimated Monthly Cost

With 10 devices sending data every 5 minutes:
- **Storage:** ~$3/month (compressed, lifecycle)
- **Queries:** ~$0.25/month (typical usage)
- **Total:** **$3-5/month**

Compare to traditional data warehouse: $1,000-3,000/month

## 🧹 Cleanup

When done testing:

```bash
cd terraform
terraform destroy -auto-approve
```

## ❓ Troubleshooting

**Issue:** Terraform apply fails with "bucket name already exists"
**Fix:** Edit `terraform/variables.tf` and change `project_name`

**Issue:** Python script fails with "Access Denied"
**Fix:** Verify AWS credentials: `aws sts get-caller-identity`

**Issue:** Athena returns no results
**Fix:** Check data exists: `aws s3 ls s3://<BUCKET>/telemetry/ --recursive`

## 📖 Full Documentation

For complete documentation, see:
- [DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md) - Detailed setup
- [USAGE-EXAMPLES.md](docs/USAGE-EXAMPLES.md) - Query patterns
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - System design
- [DEA-C01-COST-OPTIMIZATION.md](docs/DEA-C01-COST-OPTIMIZATION.md) - Cost strategies
