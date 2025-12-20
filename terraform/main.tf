# Cost-Optimized IoT Data Cataloging Solution using AWS Glue
# DEA-C01 Best Practices: Serverless, pay-per-use, no persistent compute

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "IoT-Data-Cataloging"
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Analytics"
    }
  }
}

# S3 Bucket for IoT Data Storage with Cost Optimization
resource "aws_s3_bucket" "iot_data" {
  bucket = "${var.project_name}-iot-data-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "IoT Data Storage"
    Purpose     = "Store raw IoT JSON data"
    CostOptimization = "Lifecycle policies enabled"
  }
}

# Enable versioning for data protection
resource "aws_s3_bucket_versioning" "iot_data" {
  bucket = aws_s3_bucket.iot_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for security
resource "aws_s3_bucket_server_side_encryption_configuration" "iot_data" {
  bucket = aws_s3_bucket.iot_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Cost Optimization: Lifecycle policy to transition data to cheaper storage
resource "aws_s3_bucket_lifecycle_configuration" "iot_data" {
  bucket = aws_s3_bucket.iot_data.id

  rule {
    id     = "transition-to-intelligent-tiering"
    status = "Enabled"

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER_IR"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "iot_data" {
  bucket = aws_s3_bucket.iot_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# AWS Glue Data Catalog Database
resource "aws_glue_catalog_database" "iot_catalog" {
  name        = "${var.project_name}_iot_catalog_${var.environment}"
  description = "Data catalog for IoT device telemetry data"

  tags = {
    Purpose          = "IoT Data Catalog"
    CostOptimization = "Serverless metadata store"
  }
}

# AWS Glue Schema Registry for Schema Evolution
resource "aws_glue_registry" "iot_schema_registry" {
  registry_name = "${var.project_name}-iot-schema-registry-${var.environment}"
  description   = "Schema registry for managing IoT device data schema evolution"

  tags = {
    Purpose          = "Schema Evolution Management"
    CostOptimization = "Pay-per-schema-version"
  }
}

# Schema for IoT Device Telemetry
resource "aws_glue_schema" "device_telemetry" {
  schema_name       = "iot-device-telemetry"
  registry_arn      = aws_glue_registry.iot_schema_registry.arn
  data_format       = "JSON"
  compatibility     = "BACKWARD"
  description       = "Schema for IoT device telemetry data with backward compatibility"

  schema_definition = jsonencode({
    "$schema" : "http://json-schema.org/draft-07/schema#",
    "type" : "object",
    "properties" : {
      "deviceId" : {
        "type" : "string",
        "description" : "Unique identifier for the IoT device"
      },
      "timestamp" : {
        "type" : "string",
        "format" : "date-time",
        "description" : "Timestamp when the data was collected"
      },
      "temperature" : {
        "type" : "number",
        "description" : "Temperature reading in Celsius"
      },
      "humidity" : {
        "type" : "number",
        "description" : "Humidity percentage"
      },
      "pressure" : {
        "type" : "number",
        "description" : "Atmospheric pressure in hPa"
      }
    },
    "required" : ["deviceId", "timestamp", "temperature"]
  })

  tags = {
    Version = "1.0"
    Purpose = "Device telemetry schema"
  }
}

# Glue Table for IoT Data with Partitioning for Cost Optimization
resource "aws_glue_catalog_table" "iot_telemetry" {
  name          = "iot_telemetry"
  database_name = aws_glue_catalog_database.iot_catalog.name
  description   = "Partitioned table for IoT device telemetry data"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"        = "json"
    "compressionType"       = "gzip"
    "typeOfData"            = "file"
    "skip.header.line.count" = "0"
    "projection.enabled"    = "true"
    "projection.year.type"  = "integer"
    "projection.year.range" = "2020,2030"
    "projection.month.type" = "integer"
    "projection.month.range" = "1,12"
    "projection.month.digits" = "2"
    "projection.day.type"   = "integer"
    "projection.day.range"  = "1,31"
    "projection.day.digits" = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.iot_data.bucket}/telemetry/year=$${year}/month=$${month}/day=$${day}"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.iot_data.bucket}/telemetry/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "JsonSerDe"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "deviceid"
      type = "string"
    }

    columns {
      name = "timestamp"
      type = "string"
    }

    columns {
      name = "temperature"
      type = "double"
    }

    columns {
      name = "humidity"
      type = "double"
    }

    columns {
      name = "pressure"
      type = "double"
    }

    compressed = true
  }

  # Partition keys for cost-optimized queries
  partition_keys {
    name = "year"
    type = "int"
  }

  partition_keys {
    name = "month"
    type = "int"
  }

  partition_keys {
    name = "day"
    type = "int"
  }
}

# IAM Role for Analytics Read Access
resource "aws_iam_role" "analytics_read_role" {
  name               = "${var.project_name}-analytics-read-${var.environment}"
  description        = "Role for analytics teams to query IoT data via Athena"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "analytics-team"
          }
        }
      }
    ]
  })

  tags = {
    Purpose = "Analytics team read-only access"
  }
}

# IAM Policy for Analytics Read Access
resource "aws_iam_policy" "analytics_read_policy" {
  name        = "${var.project_name}-analytics-read-policy-${var.environment}"
  description = "Read-only access to IoT data catalog and S3 data"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueCatalogReadAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:GetSchema",
          "glue:GetSchemaVersion",
          "glue:ListSchemas",
          "glue:ListSchemaVersions"
        ]
        Resource = [
          aws_glue_catalog_database.iot_catalog.arn,
          "${aws_glue_catalog_database.iot_catalog.arn}/*",
          aws_glue_registry.iot_schema_registry.arn,
          "${aws_glue_registry.iot_schema_registry.arn}/*"
        ]
      },
      {
        Sid    = "S3ReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.iot_data.arn,
          "${aws_s3_bucket.iot_data.arn}/*"
        ]
      },
      {
        Sid    = "AthenaQueryAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "AthenaResultsBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::aws-athena-query-results-*/*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "analytics_read_attachment" {
  role       = aws_iam_role.analytics_read_role.name
  policy_arn = aws_iam_policy.analytics_read_policy.arn
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
