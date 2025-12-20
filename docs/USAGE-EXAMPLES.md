# Usage Examples

## Overview
This document provides practical examples for querying and analyzing IoT data using Amazon Athena and AWS Glue.

## Table of Contents
1. [Basic Queries](#basic-queries)
2. [Aggregation Queries](#aggregation-queries)
3. [Time-Series Analysis](#time-series-analysis)
4. [Schema Evolution Queries](#schema-evolution-queries)
5. [Cost-Optimized Query Patterns](#cost-optimized-query-patterns)
6. [Python Data Generation Examples](#python-data-generation-examples)

---

## Basic Queries

### 1. View All Tables in Database
```sql
SHOW TABLES IN iot_catalog_iot_catalog_dev;
```

### 2. Describe Table Schema
```sql
DESCRIBE iot_catalog_iot_catalog_dev.iot_telemetry;
```

### 3. Preview Sample Data
```sql
SELECT * 
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12 AND day = 16
LIMIT 10;
```

### 4. Count Total Records
```sql
SELECT COUNT(*) as total_records
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12;
```

### 5. List Distinct Devices
```sql
SELECT DISTINCT deviceid
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
ORDER BY deviceid;
```

---

## Aggregation Queries

### 1. Average Temperature by Device
```sql
SELECT 
    deviceid,
    AVG(temperature) as avg_temperature,
    MIN(temperature) as min_temperature,
    MAX(temperature) as max_temperature,
    STDDEV(temperature) as temp_stddev,
    COUNT(*) as reading_count
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
GROUP BY deviceid
ORDER BY avg_temperature DESC;
```

### 2. Daily Statistics
```sql
SELECT 
    year,
    month,
    day,
    COUNT(*) as total_readings,
    COUNT(DISTINCT deviceid) as active_devices,
    AVG(temperature) as avg_temp,
    AVG(humidity) as avg_humidity,
    AVG(pressure) as avg_pressure
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
GROUP BY year, month, day
ORDER BY year, month, day;
```

### 3. Temperature Ranges
```sql
SELECT 
    CASE 
        WHEN temperature < 20 THEN 'Cold'
        WHEN temperature BETWEEN 20 AND 25 THEN 'Comfortable'
        WHEN temperature > 25 THEN 'Hot'
    END as temperature_category,
    COUNT(*) as reading_count,
    COUNT(DISTINCT deviceid) as device_count
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
GROUP BY 
    CASE 
        WHEN temperature < 20 THEN 'Cold'
        WHEN temperature BETWEEN 20 AND 25 THEN 'Comfortable'
        WHEN temperature > 25 THEN 'Hot'
    END
ORDER BY reading_count DESC;
```

---

## Time-Series Analysis

### 1. Hourly Temperature Trends
```sql
SELECT 
    deviceid,
    DATE_TRUNC('hour', CAST(timestamp AS TIMESTAMP)) as hour,
    AVG(temperature) as avg_temp,
    MIN(temperature) as min_temp,
    MAX(temperature) as max_temp
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12 AND day = 16
GROUP BY deviceid, DATE_TRUNC('hour', CAST(timestamp AS TIMESTAMP))
ORDER BY deviceid, hour;
```

### 2. Detect Temperature Anomalies
```sql
WITH device_stats AS (
    SELECT 
        deviceid,
        AVG(temperature) as avg_temp,
        STDDEV(temperature) as stddev_temp
    FROM iot_catalog_iot_catalog_dev.iot_telemetry
    WHERE year = 2024 AND month = 12
    GROUP BY deviceid
)
SELECT 
    t.deviceid,
    t.timestamp,
    t.temperature,
    s.avg_temp,
    ABS(t.temperature - s.avg_temp) / s.stddev_temp as z_score
FROM iot_catalog_iot_catalog_dev.iot_telemetry t
JOIN device_stats s ON t.deviceid = s.deviceid
WHERE year = 2024 AND month = 12
    AND ABS(t.temperature - s.avg_temp) / s.stddev_temp > 2
ORDER BY z_score DESC;
```

### 3. Moving Average (7-day)
```sql
SELECT 
    deviceid,
    timestamp,
    temperature,
    AVG(temperature) OVER (
        PARTITION BY deviceid 
        ORDER BY timestamp 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as moving_avg_7
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12 AND deviceid = 'device-0001'
ORDER BY timestamp;
```

---

## Schema Evolution Queries

### 1. Check for Schema v2 Fields (with NULL handling)
```sql
SELECT 
    deviceid,
    timestamp,
    temperature,
    humidity,
    pressure,
    battery_level,
    signal_strength,
    CASE 
        WHEN battery_level IS NOT NULL THEN 'v2'
        ELSE 'v1'
    END as schema_version
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
LIMIT 100;
```

### 2. Count Records by Schema Version
```sql
SELECT 
    CASE 
        WHEN battery_level IS NOT NULL THEN 'Schema v2'
        ELSE 'Schema v1'
    END as schema_version,
    COUNT(*) as record_count,
    COUNT(DISTINCT deviceid) as device_count
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
GROUP BY 
    CASE 
        WHEN battery_level IS NOT NULL THEN 'Schema v2'
        ELSE 'Schema v1'
    END;
```

### 3. Battery Level Analysis (v2 only)
```sql
SELECT 
    deviceid,
    AVG(battery_level) as avg_battery,
    MIN(battery_level) as min_battery,
    MAX(battery_level) as max_battery,
    COUNT(*) as reading_count
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
    AND battery_level IS NOT NULL
GROUP BY deviceid
ORDER BY avg_battery ASC;
```

### 4. Low Battery Alerts
```sql
SELECT 
    deviceid,
    timestamp,
    battery_level,
    signal_strength
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
    AND battery_level < 20
ORDER BY battery_level ASC, timestamp DESC;
```

---

## Cost-Optimized Query Patterns

### 1. Always Use Partition Filters (Best Practice)
```sql
-- ✅ GOOD: Uses partition pruning
SELECT AVG(temperature) as avg_temp
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 
    AND month = 12 
    AND day = 16;  -- Scans only 1 day

-- ❌ BAD: Full table scan
SELECT AVG(temperature) as avg_temp
FROM iot_catalog_iot_catalog_dev.iot_telemetry;  -- Scans all data!
```

### 2. Select Only Needed Columns
```sql
-- ✅ GOOD: Selects only needed columns
SELECT deviceid, temperature
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12;

-- ❌ BAD: Selects all columns
SELECT *
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12;
```

### 3. Use LIMIT for Exploratory Queries
```sql
-- ✅ GOOD: Limited result set for testing
SELECT *
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
LIMIT 100;
```

### 4. Leverage Aggregate Pushdown
```sql
-- ✅ GOOD: Aggregation reduces data transfer
SELECT 
    deviceid,
    DATE(CAST(timestamp AS TIMESTAMP)) as date,
    AVG(temperature) as avg_temp
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
GROUP BY deviceid, DATE(CAST(timestamp AS TIMESTAMP));
```

### 5. Cost Estimation Query
```sql
-- Check data size for cost estimation
SELECT 
    '$' || CAST(ROUND(SUM(bytes) / 1024.0 / 1024.0 / 1024.0 / 1024.0 * 5, 4) AS VARCHAR) as estimated_cost,
    ROUND(SUM(bytes) / 1024.0 / 1024.0 / 1024.0, 2) as size_gb
FROM (
    SELECT SUM(size) as bytes
    FROM information_schema.table_storage
    WHERE table_schema = 'iot_catalog_iot_catalog_dev'
        AND table_name = 'iot_telemetry'
);
```

---

## Python Data Generation Examples

### Example 1: Generate Single Day of Data (Schema v1)
```bash
python iot_data_generator.py \
  --bucket iot-catalog-iot-data-dev-123456789012 \
  --registry iot-catalog-iot-schema-registry-dev \
  --region us-east-1 \
  --devices 10 \
  --readings 288 \
  --days 1 \
  --schema-version 1
```

**Output:**
- 10 devices × 288 readings = 2,880 records
- Uploaded to: `s3://bucket/telemetry/year=2024/month=12/day=16/`
- File size: ~300KB (compressed)

### Example 2: Generate Week of Data (Schema v2)
```bash
python iot_data_generator.py \
  --bucket iot-catalog-iot-data-dev-123456789012 \
  --registry iot-catalog-iot-schema-registry-dev \
  --region us-east-1 \
  --devices 25 \
  --readings 288 \
  --days 7 \
  --schema-version 2
```

**Output:**
- 25 devices × 288 readings × 7 days = 50,400 records
- Uploaded to 7 different partition paths
- Total size: ~5MB (compressed)

### Example 3: Schema Management
```bash
# List all schema versions
python schema_manager.py \
  --registry iot-catalog-iot-schema-registry-dev \
  --action list-versions \
  --schema-name iot-device-telemetry

# Register new schema version (v2)
python schema_manager.py \
  --registry iot-catalog-iot-schema-registry-dev \
  --action register-v2 \
  --schema-name iot-device-telemetry

# Check compatibility
python schema_manager.py \
  --registry iot-catalog-iot-schema-registry-dev \
  --action check-compatibility \
  --schema-name iot-device-telemetry
```

---

## Advanced Analytics Examples

### 1. Device Correlation Analysis
```sql
SELECT 
    a.deviceid as device_a,
    b.deviceid as device_b,
    CORR(a.temperature, b.temperature) as temp_correlation
FROM iot_catalog_iot_catalog_dev.iot_telemetry a
JOIN iot_catalog_iot_catalog_dev.iot_telemetry b
    ON a.timestamp = b.timestamp
    AND a.deviceid < b.deviceid
WHERE a.year = 2024 AND a.month = 12
    AND b.year = 2024 AND b.month = 12
GROUP BY a.deviceid, b.deviceid
HAVING CORR(a.temperature, b.temperature) > 0.8
ORDER BY temp_correlation DESC;
```

### 2. Percentile Analysis
```sql
SELECT 
    deviceid,
    APPROX_PERCENTILE(temperature, 0.25) as p25_temp,
    APPROX_PERCENTILE(temperature, 0.50) as median_temp,
    APPROX_PERCENTILE(temperature, 0.75) as p75_temp,
    APPROX_PERCENTILE(temperature, 0.95) as p95_temp
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
GROUP BY deviceid
ORDER BY deviceid;
```

### 3. Data Quality Check
```sql
SELECT 
    year,
    month,
    day,
    COUNT(*) as total_records,
    SUM(CASE WHEN temperature IS NULL THEN 1 ELSE 0 END) as null_temperature,
    SUM(CASE WHEN humidity IS NULL THEN 1 ELSE 0 END) as null_humidity,
    SUM(CASE WHEN pressure IS NULL THEN 1 ELSE 0 END) as null_pressure,
    SUM(CASE WHEN temperature < -50 OR temperature > 100 THEN 1 ELSE 0 END) as invalid_temp,
    CAST(SUM(CASE WHEN temperature IS NULL THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*) * 100 as null_percentage
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
GROUP BY year, month, day
ORDER BY year, month, day;
```

---

## Query Performance Tips

1. **Always filter by partitions first**
   - Include `WHERE year = X AND month = Y` in every query
   - This reduces data scanned by 90%+

2. **Use columnar formats when possible**
   - Convert JSON to Parquet for better compression
   - Parquet reduces query costs by 3-5x

3. **Create views for common queries**
   ```sql
   CREATE VIEW daily_device_summary AS
   SELECT 
       year, month, day,
       deviceid,
       AVG(temperature) as avg_temp,
       COUNT(*) as readings
   FROM iot_catalog_iot_catalog_dev.iot_telemetry
   GROUP BY year, month, day, deviceid;
   ```

4. **Use CTAS for intermediate results**
   ```sql
   CREATE TABLE filtered_data AS
   SELECT * FROM iot_telemetry
   WHERE year = 2024 AND month = 12
       AND temperature > 25;
   ```

5. **Monitor query costs**
   ```sql
   -- Check in AWS Console: Athena > Recent queries > Data scanned
   -- Target: < 100MB per query for exploration
   ```

---

## Common Pitfalls to Avoid

❌ **Don't:** Run queries without partition filters
✅ **Do:** Always include year/month/day in WHERE clause

❌ **Don't:** Use `SELECT *` for production queries
✅ **Do:** Select only the columns you need

❌ **Don't:** Create tables without partitioning
✅ **Do:** Use partition projection for automatic discovery

❌ **Don't:** Store uncompressed data
✅ **Do:** Use gzip or other compression

❌ **Don't:** Ignore schema evolution
✅ **Do:** Handle NULL values for new fields gracefully

---

## Next Steps

- Review [DEA-C01-COST-OPTIMIZATION.md](DEA-C01-COST-OPTIMIZATION.md) for cost-saving strategies
- Explore [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- Check [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for setup instructions
