# Outputs for the IoT data cataloging solution

output "s3_bucket_name" {
  description = "Name of the S3 bucket storing IoT data"
  value       = aws_s3_bucket.iot_data.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket storing IoT data"
  value       = aws_s3_bucket.iot_data.arn
}

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = aws_glue_catalog_database.iot_catalog.name
}

output "glue_table_name" {
  description = "Name of the Glue catalog table for IoT telemetry"
  value       = aws_glue_catalog_table.iot_telemetry.name
}

output "schema_registry_arn" {
  description = "ARN of the Glue Schema Registry"
  value       = aws_glue_registry.iot_schema_registry.arn
}

output "schema_registry_name" {
  description = "Name of the Glue Schema Registry"
  value       = aws_glue_registry.iot_schema_registry.registry_name
}

output "analytics_role_arn" {
  description = "ARN of the IAM role for analytics team read access"
  value       = aws_iam_role.analytics_read_role.arn
}

output "analytics_policy_arn" {
  description = "ARN of the IAM policy for analytics team read access"
  value       = aws_iam_policy.analytics_read_policy.arn
}

output "athena_query_location" {
  description = "S3 location for Athena query results"
  value       = "s3://aws-athena-query-results-${data.aws_caller_identity.current.account_id}-${var.aws_region}/"
}

output "sample_athena_query" {
  description = "Sample Athena query for analytics team"
  value       = <<-EOT
    SELECT 
      deviceid,
      AVG(temperature) as avg_temperature,
      AVG(humidity) as avg_humidity,
      COUNT(*) as reading_count
    FROM ${aws_glue_catalog_database.iot_catalog.name}.${aws_glue_catalog_table.iot_telemetry.name}
    WHERE year = 2024 AND month = 12
    GROUP BY deviceid
    ORDER BY avg_temperature DESC;
  EOT
}
