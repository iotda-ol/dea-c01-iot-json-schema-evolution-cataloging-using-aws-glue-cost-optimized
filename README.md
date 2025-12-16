# Cost-Optimized IoT Data Cataloging with AWS Glue

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Glue%20%7C%20S3%20%7C%20Athena-orange.svg)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/)

## Overview

This repository demonstrates a **cost-effective, serverless solution** for cataloging evolving IoT JSON data stored in Amazon S3. It leverages **AWS Glue Data Catalog** for metadata indexing, **AWS Glue Schema Registry** for schema evolution management, and **Amazon Athena** for serverless analytics—all without provisioning persistent compute resources.

**Aligned with DEA-C01 (AWS Certified Data Engineer - Associate) best practices**, this solution achieves **95-99% cost savings** compared to traditional data warehouse approaches while maintaining full analytics capabilities.

## ✨ Key Features

- **🚀 Serverless Architecture:** Zero persistent compute costs, pay only for usage
- **💰 Cost-Optimized Storage:** Intelligent Tiering, lifecycle policies, 70% compression
- **📊 Schema Evolution:** Backward-compatible schema versioning with AWS Glue Schema Registry
- **🔍 Partition Pruning:** Date-based partitioning reduces query costs by 90%+
- **🔐 Secure Access:** IAM-based read-only access for analytics teams
- **📈 Scalable:** Handles millions of IoT events without infrastructure changes
- **🛠️ Infrastructure as Code:** Complete Terraform deployment for reproducibility
- **📝 Comprehensive Documentation:** Architecture, deployment, usage examples, and cost optimization guides

## 🏗️ Architecture

```
IoT Devices → Python Generator → Schema Registry → S3 (Partitioned) → Glue Catalog → Athena → Analytics
```

### Core Components

| Component | Purpose | Cost Optimization |
|-----------|---------|-------------------|
| **Amazon S3** | Raw data storage | Intelligent Tiering, lifecycle policies, compression |
| **AWS Glue Data Catalog** | Metadata repository | Serverless, partition projection |
| **AWS Glue Schema Registry** | Schema versioning | Pay-per-version, backward compatibility |
| **Amazon Athena** | Serverless SQL queries | Pay-per-query, partition pruning |
| **IAM Roles** | Read-only access | No data warehouse loading required |

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed design documentation.

## 💰 Cost Benefits

### Monthly Cost Comparison

| Approach | Infrastructure | Storage | Compute | Monthly Total |
|----------|---------------|---------|---------|---------------|
| **Traditional Data Warehouse** | Redshift cluster | Uncompressed | 24/7 running | $1,000-3,000 |
| **This Solution** | None (serverless) | Compressed + tiering | Pay-per-query | $3-60 |
| **Savings** | - | **83%** | **100%** | **95-99%** |

### Cost Optimization Features

✅ **S3 Intelligent Tiering:** Automatically moves data to optimal storage tier (46% savings)  
✅ **Lifecycle Policies:** Archives to Glacier after 90 days (83% savings)  
✅ **gzip Compression:** Reduces storage and query costs by 70%  
✅ **Partition Pruning:** Scans only relevant data (90%+ query cost reduction)  
✅ **Serverless Compute:** Zero idle costs with Athena and Glue  
✅ **No ETL Loading:** Direct querying eliminates data warehouse costs  

See [DEA-C01-COST-OPTIMIZATION.md](docs/DEA-C01-COST-OPTIMIZATION.md) for complete cost analysis.

## 🚀 Quick Start

### Prerequisites

- **Terraform** >= 1.0
- **AWS CLI** >= 2.0
- **Python** >= 3.8
- AWS account with appropriate permissions

### 1. Clone Repository

```bash
git clone https://github.com/iotda-ol/dea-c01-iot-json-schema-evolution-cataloging-using-aws-glue-cost-optimized.git
cd dea-c01-iot-json-schema-evolution-cataloging-using-aws-glue-cost-optimized
```

### 2. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

### 3. Generate Sample Data

```bash
cd ../src/python
pip install -r requirements.txt

# Generate IoT telemetry data
python iot_data_generator.py \
  --bucket <S3_BUCKET_NAME> \
  --registry <SCHEMA_REGISTRY_NAME> \
  --devices 10 \
  --readings 288 \
  --days 7 \
  --schema-version 1
```

### 4. Query with Athena

```sql
SELECT 
    deviceid,
    AVG(temperature) as avg_temp,
    COUNT(*) as readings
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
GROUP BY deviceid;
```

See [DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md) for detailed setup instructions.

## 📂 Repository Structure

```
.
├── README.md                   # This file
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                # Main Terraform configuration
│   ├── variables.tf           # Input variables
│   └── outputs.tf             # Output values
├── src/python/                # Python application code
│   ├── iot_data_generator.py # IoT data generation script
│   ├── schema_manager.py     # Schema registry management
│   └── requirements.txt       # Python dependencies
├── docs/                      # Documentation
│   ├── ARCHITECTURE.md        # Architecture design document
│   ├── DEPLOYMENT-GUIDE.md    # Deployment instructions
│   ├── USAGE-EXAMPLES.md      # Query examples and patterns
│   └── DEA-C01-COST-OPTIMIZATION.md  # Cost optimization guide
└── examples/                  # Sample files
    ├── sample_telemetry_v1.json
    ├── sample_telemetry_v2.json
    └── sample_athena_queries.sql
```

## 📚 Documentation

### Core Documentation

- **[Architecture Design](docs/ARCHITECTURE.md)** - System architecture, data flow, components
- **[Deployment Guide](docs/DEPLOYMENT-GUIDE.md)** - Step-by-step setup instructions
- **[Usage Examples](docs/USAGE-EXAMPLES.md)** - Query patterns, Python scripts, best practices
- **[Cost Optimization](docs/DEA-C01-COST-OPTIMIZATION.md)** - DEA-C01 exam tips, cost strategies

### Example Queries

See [examples/sample_athena_queries.sql](examples/sample_athena_queries.sql) for ready-to-use SQL queries.

## 🔄 Schema Evolution

This solution supports backward-compatible schema evolution:

### Schema v1 (Initial)
```json
{
  "deviceId": "device-0001",
  "timestamp": "2024-12-16T10:30:00Z",
  "temperature": 22.5,
  "humidity": 65.3,
  "pressure": 1013.2
}
```

### Schema v2 (Evolved - with new optional fields)
```json
{
  "deviceId": "device-0001",
  "timestamp": "2024-12-16T10:30:00Z",
  "temperature": 22.5,
  "humidity": 65.3,
  "pressure": 1013.2,
  "battery_level": 87.4,
  "signal_strength": -67
}
```

AWS Glue Schema Registry ensures:
- ✅ Old consumers can read new data (ignore unknown fields)
- ✅ New consumers can read old data (handle missing fields)
- ✅ Schema compatibility enforced automatically

## 🎯 DEA-C01 Alignment

This project demonstrates key DEA-C01 exam objectives:

### Domain 2: Data Store Management (26%)
- ✅ Task 2.3: Optimize data storage costs (S3 tiering, compression, lifecycle)

### Domain 3: Data Operations and Support (22%)
- ✅ Task 3.1: Optimize data pipelines (serverless, partitioning, schema evolution)

### Domain 4: Data Security and Governance (24%)
- ✅ Task 4.2: Implement security controls (IAM, encryption, tagging)

## 🛠️ Technologies Used

- **AWS Services:** S3, Glue Data Catalog, Glue Schema Registry, Athena, IAM
- **Infrastructure:** Terraform (IaC)
- **Programming:** Python 3.8+, boto3
- **Data Formats:** JSON, gzip compression
- **Query Language:** SQL (Athena)

## 📊 Use Cases

This solution is ideal for:

✅ IoT telemetry data cataloging  
✅ Ad-hoc analytics and exploration  
✅ Cost-sensitive analytics workloads  
✅ Schema evolution requirements  
✅ Multi-team data access (read-only)  
✅ Audit and compliance reporting  
✅ Data lake implementations  

## 🔒 Security

- Server-side encryption (AES256) for S3
- IAM least-privilege access controls
- Read-only access for analytics teams
- Public access blocked on S3 buckets
- Resource tagging for governance

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Support

For issues or questions:
1. Check the [Documentation](docs/)
2. Review [Usage Examples](docs/USAGE-EXAMPLES.md)
3. Open an issue on GitHub

## 🙏 Acknowledgments

This project demonstrates AWS best practices for:
- DEA-C01 (AWS Certified Data Engineer - Associate) exam preparation
- Cost-optimized data engineering solutions
- Serverless data architectures
- Schema evolution management

---

**Built with ❤️ for cost-conscious data engineers**
