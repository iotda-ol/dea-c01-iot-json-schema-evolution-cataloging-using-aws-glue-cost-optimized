#!/usr/bin/env python3
"""
IoT Device Data Generator
Generates simulated IoT device telemetry data and uploads to S3
Supports schema evolution through AWS Glue Schema Registry
"""

import json
import random
import gzip
from datetime import datetime, timedelta
from typing import List, Dict
import boto3
from botocore.exceptions import ClientError
import argparse
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class IoTDataGenerator:
    """Generates and uploads IoT device telemetry data"""
    
    def __init__(self, bucket_name: str, schema_registry_name: str, region: str = 'us-east-1'):
        self.bucket_name = bucket_name
        self.schema_registry_name = schema_registry_name
        self.region = region
        self.s3_client = boto3.client('s3', region_name=region)
        self.glue_client = boto3.client('glue', region_name=region)
        
    def generate_telemetry_v1(self, device_id: str, timestamp: datetime) -> Dict:
        """Generate telemetry data using schema v1 (basic fields)"""
        return {
            "deviceId": device_id,
            "timestamp": timestamp.isoformat(),
            "temperature": round(random.uniform(15.0, 35.0), 2),
            "humidity": round(random.uniform(30.0, 80.0), 2),
            "pressure": round(random.uniform(980.0, 1030.0), 2)
        }
    
    def generate_telemetry_v2(self, device_id: str, timestamp: datetime) -> Dict:
        """Generate telemetry data using schema v2 (added fields for evolution)"""
        data = self.generate_telemetry_v1(device_id, timestamp)
        # Schema evolution: add new optional fields
        data.update({
            "battery_level": round(random.uniform(0.0, 100.0), 2),
            "signal_strength": random.randint(-100, -30)
        })
        return data
    
    def validate_schema(self, data: Dict, schema_version: int = 1) -> bool:
        """Validate data against schema"""
        required_fields_v1 = ["deviceId", "timestamp", "temperature"]
        
        # Check required fields
        if not all(field in data for field in required_fields_v1):
            logger.error(f"Missing required fields. Data: {data}")
            return False
        
        return True
    
    def generate_batch_data(
        self, 
        device_ids: List[str], 
        start_date: datetime,
        num_readings_per_device: int = 100,
        schema_version: int = 1
    ) -> List[Dict]:
        """Generate batch telemetry data for multiple devices"""
        all_data = []
        
        for device_id in device_ids:
            for i in range(num_readings_per_device):
                # Generate readings at 5-minute intervals
                timestamp = start_date + timedelta(minutes=i * 5)
                
                if schema_version == 1:
                    data = self.generate_telemetry_v1(device_id, timestamp)
                else:
                    data = self.generate_telemetry_v2(device_id, timestamp)
                
                if self.validate_schema(data, schema_version):
                    all_data.append(data)
        
        logger.info(f"Generated {len(all_data)} telemetry readings")
        return all_data
    
    def upload_to_s3(
        self, 
        data: List[Dict], 
        date: datetime,
        compress: bool = True
    ) -> str:
        """Upload telemetry data to S3 with partitioning"""
        # Create partition path: year/month/day
        year = date.year
        month = str(date.month).zfill(2)
        day = str(date.day).zfill(2)
        
        timestamp_str = date.strftime("%Y%m%d_%H%M%S")
        filename = f"telemetry_{timestamp_str}.json"
        
        if compress:
            filename += ".gz"
        
        s3_key = f"telemetry/year={year}/month={month}/day={day}/{filename}"
        
        # Convert data to JSON lines format
        json_data = '\n'.join(json.dumps(record) for record in data)
        
        try:
            if compress:
                # Compress data using gzip
                compressed_data = gzip.compress(json_data.encode('utf-8'))
                self.s3_client.put_object(
                    Bucket=self.bucket_name,
                    Key=s3_key,
                    Body=compressed_data,
                    ContentType='application/json',
                    ContentEncoding='gzip',
                    ServerSideEncryption='AES256'
                )
            else:
                self.s3_client.put_object(
                    Bucket=self.bucket_name,
                    Key=s3_key,
                    Body=json_data.encode('utf-8'),
                    ContentType='application/json',
                    ServerSideEncryption='AES256'
                )
            
            logger.info(f"Successfully uploaded data to s3://{self.bucket_name}/{s3_key}")
            return s3_key
            
        except ClientError as e:
            logger.error(f"Failed to upload to S3: {e}")
            raise
    
    def register_schema_version(self, schema_name: str, schema_definition: Dict, version: str):
        """Register a new schema version in Glue Schema Registry"""
        try:
            response = self.glue_client.register_schema_version(
                SchemaId={
                    'SchemaName': schema_name,
                    'RegistryName': self.schema_registry_name
                },
                SchemaDefinition=json.dumps(schema_definition)
            )
            logger.info(f"Registered schema version {version}: {response['VersionNumber']}")
            return response
        except ClientError as e:
            if e.response['Error']['Code'] == 'AlreadyExistsException':
                logger.info(f"Schema version {version} already exists")
            else:
                logger.error(f"Failed to register schema: {e}")


def main():
    parser = argparse.ArgumentParser(description='Generate and upload IoT telemetry data')
    parser.add_argument('--bucket', required=True, help='S3 bucket name')
    parser.add_argument('--registry', default='iot-catalog-iot-schema-registry-dev', 
                       help='Glue Schema Registry name')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--devices', type=int, default=5, help='Number of devices')
    parser.add_argument('--readings', type=int, default=100, 
                       help='Number of readings per device')
    parser.add_argument('--schema-version', type=int, default=1, choices=[1, 2],
                       help='Schema version to use (1 or 2)')
    parser.add_argument('--days', type=int, default=1, 
                       help='Number of days of data to generate')
    
    args = parser.parse_args()
    
    # Initialize generator
    generator = IoTDataGenerator(
        bucket_name=args.bucket,
        schema_registry_name=args.registry,
        region=args.region
    )
    
    # Generate device IDs
    device_ids = [f"device-{i:04d}" for i in range(1, args.devices + 1)]
    logger.info(f"Generating data for devices: {device_ids}")
    
    # Generate data for multiple days
    start_date = datetime.now() - timedelta(days=args.days)
    
    for day_offset in range(args.days):
        current_date = start_date + timedelta(days=day_offset)
        
        # Generate batch data
        data = generator.generate_batch_data(
            device_ids=device_ids,
            start_date=current_date,
            num_readings_per_device=args.readings,
            schema_version=args.schema_version
        )
        
        # Upload to S3
        s3_key = generator.upload_to_s3(data, current_date, compress=True)
        logger.info(f"Uploaded {len(data)} records for {current_date.date()}")
    
    logger.info("Data generation completed successfully")


if __name__ == "__main__":
    main()
