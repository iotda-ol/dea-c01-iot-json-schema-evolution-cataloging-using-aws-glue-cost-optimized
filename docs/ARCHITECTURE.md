# Architecture Design Document

## Overview
This solution provides a cost-optimized IoT data cataloging system using AWS Glue, Amazon S3, and serverless technologies. It follows DEA-C01 (AWS Certified Data Engineer - Associate) best practices for building scalable, cost-effective data solutions.

## Architecture Diagram

```
┌─────────────────┐
│  IoT Devices    │
│  (Simulated)    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│              Python Data Generator                       │
│  - Generates telemetry data                             │
│  - Validates against schema                             │
│  - Compresses (gzip) before upload                      │
└────────┬────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│           AWS Glue Schema Registry                       │
│  - Schema versioning (v1, v2)                           │
│  - Backward compatibility enforcement                    │
│  - Schema evolution tracking                            │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│              Amazon S3 (IoT Data Lake)                   │
│  Storage Structure:                                      │
│  s3://bucket/telemetry/                                 │
│    ├── year=2024/                                       │
│    │   ├── month=12/                                    │
│    │   │   ├── day=01/                                  │
│    │   │   │   └── telemetry_*.json.gz                 │
│    │   │   └── day=02/...                              │
│  Features:                                              │
│  - Intelligent Tiering (auto cost optimization)         │
│  - Lifecycle policies (Glacier after 90 days)           │
│  - Versioning enabled                                   │
│  - Server-side encryption (AES256)                      │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│         AWS Glue Data Catalog                           │
│  Database: iot_catalog_dev                              │
│  Table: iot_telemetry                                   │
│  - Partitioned by year/month/day                        │
│  - Partition projection enabled (no MSCK needed)        │
│  - JSON SerDe for querying                              │
│  - Compressed format support                            │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│              Amazon Athena                              │
│  - Serverless SQL queries                               │
│  - Pay-per-query pricing                                │
│  - Partition pruning for cost optimization              │
│  - No persistent compute                                │
└────────┬────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│         Analytics Teams (Read-Only Access)              │
│  Via IAM Role:                                          │
│  - Query data via Athena                                │
│  - Read from S3                                         │
│  - Access Glue Catalog metadata                         │
│  - No data warehouse loading required                   │
└─────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Amazon S3 (Data Storage)
**Purpose:** Cost-optimized storage for IoT JSON data

**Features:**
- **Partitioning:** Data organized by `year/month/day` for efficient querying
- **Compression:** gzip compression reduces storage costs by ~70%
- **Lifecycle Policies:**
  - Day 0: Intelligent Tiering (automatic cost optimization)
  - Day 90: Glacier Instant Retrieval
  - Day 180: Glacier Deep Archive
  - Day 365: Expiration
- **Security:** Server-side encryption (AES256), versioning enabled
- **Access Control:** Public access blocked

**Cost Optimization:**
- Intelligent Tiering automatically moves data between access tiers
- Lifecycle rules reduce storage costs for older data
- Compression reduces storage volume

### 2. AWS Glue Data Catalog
**Purpose:** Serverless metadata repository for IoT data

**Features:**
- **Database:** `iot_catalog_dev` - centralized metadata store
- **Table:** `iot_telemetry` - external table pointing to S3
- **Partitioning:** Year, month, day partitions for query optimization
- **Partition Projection:** Automatic partition discovery (no MSCK REPAIR needed)
- **Schema Management:** JSON SerDe for parsing JSON data

**Cost Optimization:**
- Serverless - no compute costs
- Pay only for API calls and storage (minimal)
- Partition projection eliminates manual partition management

### 3. AWS Glue Schema Registry
**Purpose:** Manage schema evolution as device formats change

**Features:**
- **Schema Versioning:** Track schema changes over time
- **Compatibility Modes:** BACKWARD compatibility ensures old readers work with new data
- **Schema Definition:** JSON Schema format with validation
- **Evolution Support:**
  - v1: deviceId, timestamp, temperature, humidity, pressure
  - v2: v1 + battery_level, signal_strength (optional fields)

**Cost Optimization:**
- Pay per schema version (one-time cost)
- No ongoing compute costs
- Prevents data quality issues that require expensive reprocessing

### 4. Amazon Athena
**Purpose:** Serverless SQL query engine for analytics

**Features:**
- **Query Language:** Standard SQL
- **Partition Pruning:** Only scans relevant partitions
- **Compression Support:** Reads gzip files natively
- **No Infrastructure:** Fully managed, serverless

**Cost Optimization:**
- Pay only for data scanned ($5 per TB)
- Partition pruning reduces data scanned
- Compression reduces data scanned by ~70%
- No idle compute costs

### 5. IAM Roles and Policies
**Purpose:** Secure, read-only access for analytics teams

**Features:**
- **Analytics Role:** Can be assumed by analytics team members
- **Read-Only Permissions:**
  - Glue Catalog: Get database, tables, partitions, schemas
  - S3: GetObject, ListBucket (no write access)
  - Athena: Query execution permissions
- **No Data Warehouse Required:** Direct querying eliminates ETL costs

## Data Flow

1. **Data Generation:**
   - IoT devices (simulated) generate telemetry data
   - Python script validates data against schema
   - Data compressed using gzip

2. **Schema Validation:**
   - Schema Manager validates against Glue Schema Registry
   - Ensures backward compatibility
   - Tracks schema versions

3. **Data Storage:**
   - Data uploaded to S3 with partition keys (year/month/day)
   - Intelligent Tiering immediately optimizes storage costs
   - Server-side encryption applied

4. **Metadata Cataloging:**
   - Glue Catalog maintains metadata about data structure
   - Partition projection automatically discovers partitions
   - No manual catalog updates needed

5. **Analytics Access:**
   - Analytics teams assume IAM role
   - Query data using Athena (serverless SQL)
   - Results returned without loading into data warehouse

## Schema Evolution Strategy

### Initial Schema (v1)
```json
{
  "deviceId": "string",
  "timestamp": "datetime",
  "temperature": "number",
  "humidity": "number",
  "pressure": "number"
}
```

### Evolved Schema (v2) - Backward Compatible
```json
{
  "deviceId": "string",
  "timestamp": "datetime", 
  "temperature": "number",
  "humidity": "number",
  "pressure": "number",
  "battery_level": "number (optional)",
  "signal_strength": "integer (optional)"
}
```

**Backward Compatibility:**
- New fields are optional
- Old consumers can still read new data (ignore unknown fields)
- New consumers can read old data (handle missing fields)

## Security Considerations

1. **Data Encryption:**
   - S3: Server-side encryption (AES256)
   - In-transit: HTTPS/TLS for all API calls

2. **Access Control:**
   - IAM roles with least privilege
   - Read-only access for analytics teams
   - No public access to S3 buckets

3. **Compliance:**
   - Data versioning for audit trails
   - CloudTrail logging (if enabled) for access auditing
   - Resource tagging for governance

## Scalability

- **S3:** Virtually unlimited storage capacity
- **Glue Catalog:** Supports millions of tables and partitions
- **Athena:** Auto-scales based on query complexity
- **No Bottlenecks:** Serverless architecture eliminates scaling concerns

## Monitoring and Observability

**Recommended CloudWatch Metrics:**
- S3: BucketSize, NumberOfObjects
- Athena: DataScannedInBytes, QueryExecutionTime
- Glue: SchemaVersionCount

**Cost Monitoring:**
- AWS Cost Explorer: Track spending by service
- Resource Tags: Enable cost allocation by project/environment
- S3 Storage Lens: Analyze storage patterns and costs

## Future Enhancements

1. **Real-time Processing:**
   - Add Amazon Kinesis for real-time data ingestion
   - AWS Lambda for stream processing

2. **Data Quality:**
   - AWS Glue DataBrew for data profiling
   - AWS Glue Data Quality rules

3. **Advanced Analytics:**
   - Amazon QuickSight for visualization
   - Amazon SageMaker for ML models

4. **Automation:**
   - EventBridge rules for automated workflows
   - Step Functions for orchestration
