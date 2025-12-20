-- Sample Athena Queries for IoT Data Catalog
-- Replace 'iot_catalog_iot_catalog_dev' with your actual database name

-- 1. Basic Query: View sample data
SELECT * 
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12 AND day = 16
LIMIT 10;

-- 2. Aggregation: Average temperature by device
SELECT 
    deviceid,
    AVG(temperature) as avg_temperature,
    MIN(temperature) as min_temperature,
    MAX(temperature) as max_temperature,
    COUNT(*) as reading_count
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
GROUP BY deviceid
ORDER BY avg_temperature DESC;

-- 3. Time Series: Hourly temperature trends
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

-- 4. Schema Evolution: Check for v2 fields
SELECT 
    deviceid,
    timestamp,
    temperature,
    battery_level,
    signal_strength,
    CASE 
        WHEN battery_level IS NOT NULL THEN 'v2'
        ELSE 'v1'
    END as schema_version
FROM iot_catalog_iot_catalog_dev.iot_telemetry
WHERE year = 2024 AND month = 12
LIMIT 100;

-- 5. Data Quality: Check for anomalies
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

-- 6. Cost-Optimized Query: Daily summary (partition pruning)
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
