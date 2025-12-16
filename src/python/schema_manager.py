#!/usr/bin/env python3
"""
AWS Glue Schema Registry Manager
Handles schema registration, evolution, and compatibility checking
"""

import json
import boto3
from botocore.exceptions import ClientError
import argparse
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class SchemaManager:
    """Manages schemas in AWS Glue Schema Registry"""
    
    def __init__(self, registry_name: str, region: str = 'us-east-1'):
        self.registry_name = registry_name
        self.region = region
        self.glue_client = boto3.client('glue', region_name=region)
    
    def get_schema_v1(self) -> dict:
        """Get schema definition version 1 (initial schema)"""
        return {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "type": "object",
            "properties": {
                "deviceId": {
                    "type": "string",
                    "description": "Unique identifier for the IoT device"
                },
                "timestamp": {
                    "type": "string",
                    "format": "date-time",
                    "description": "Timestamp when the data was collected"
                },
                "temperature": {
                    "type": "number",
                    "description": "Temperature reading in Celsius"
                },
                "humidity": {
                    "type": "number",
                    "description": "Humidity percentage"
                },
                "pressure": {
                    "type": "number",
                    "description": "Atmospheric pressure in hPa"
                }
            },
            "required": ["deviceId", "timestamp", "temperature"]
        }
    
    def get_schema_v2(self) -> dict:
        """Get schema definition version 2 (with additional fields)"""
        schema = self.get_schema_v1()
        # Add new optional fields for schema evolution
        schema["properties"]["battery_level"] = {
            "type": "number",
            "description": "Battery level percentage",
            "minimum": 0,
            "maximum": 100
        }
        schema["properties"]["signal_strength"] = {
            "type": "integer",
            "description": "Signal strength in dBm",
            "minimum": -100,
            "maximum": -30
        }
        return schema
    
    def register_schema(self, schema_name: str, schema_definition: dict, data_format: str = "JSON"):
        """Register a new schema in the registry"""
        try:
            response = self.glue_client.create_schema(
                RegistryId={'RegistryName': self.registry_name},
                SchemaName=schema_name,
                DataFormat=data_format,
                Compatibility='BACKWARD',
                Description=f'Schema for {schema_name}',
                SchemaDefinition=json.dumps(schema_definition),
                Tags={
                    'Environment': 'dev',
                    'Purpose': 'IoT telemetry'
                }
            )
            logger.info(f"Successfully registered schema: {schema_name}")
            logger.info(f"Schema ARN: {response['SchemaArn']}")
            return response
        except ClientError as e:
            if e.response['Error']['Code'] == 'AlreadyExistsException':
                logger.warning(f"Schema {schema_name} already exists")
                return self.get_schema_by_name(schema_name)
            else:
                logger.error(f"Failed to register schema: {e}")
                raise
    
    def register_schema_version(self, schema_name: str, schema_definition: dict):
        """Register a new version of an existing schema"""
        try:
            response = self.glue_client.register_schema_version(
                SchemaId={
                    'SchemaName': schema_name,
                    'RegistryName': self.registry_name
                },
                SchemaDefinition=json.dumps(schema_definition)
            )
            logger.info(f"Registered new schema version: {response['VersionNumber']}")
            logger.info(f"Status: {response['Status']}")
            return response
        except ClientError as e:
            if e.response['Error']['Code'] == 'EntityNotFoundException':
                logger.error(f"Schema {schema_name} not found. Create it first.")
            else:
                logger.error(f"Failed to register schema version: {e}")
            raise
    
    def get_schema_by_name(self, schema_name: str):
        """Get schema details by name"""
        try:
            response = self.glue_client.get_schema(
                SchemaId={
                    'SchemaName': schema_name,
                    'RegistryName': self.registry_name
                }
            )
            logger.info(f"Retrieved schema: {schema_name}")
            return response
        except ClientError as e:
            logger.error(f"Failed to get schema: {e}")
            raise
    
    def list_schema_versions(self, schema_name: str):
        """List all versions of a schema"""
        try:
            response = self.glue_client.list_schema_versions(
                SchemaId={
                    'SchemaName': schema_name,
                    'RegistryName': self.registry_name
                }
            )
            versions = response.get('Schemas', [])
            logger.info(f"Found {len(versions)} versions for schema {schema_name}")
            for version in versions:
                logger.info(f"  Version {version['VersionNumber']}: Status={version['Status']}")
            return versions
        except ClientError as e:
            logger.error(f"Failed to list schema versions: {e}")
            raise
    
    def check_schema_compatibility(self, schema_name: str, new_schema_definition: dict):
        """Check if a new schema version is compatible"""
        try:
            response = self.glue_client.check_schema_version_validity(
                DataFormat='JSON',
                SchemaDefinition=json.dumps(new_schema_definition)
            )
            
            is_valid = response['Valid']
            logger.info(f"Schema validity check: {is_valid}")
            
            if not is_valid:
                logger.error(f"Schema is not valid: {response.get('Error', 'Unknown error')}")
            
            return is_valid
        except ClientError as e:
            logger.error(f"Failed to check schema compatibility: {e}")
            raise


def main():
    parser = argparse.ArgumentParser(description='Manage AWS Glue Schema Registry')
    parser.add_argument('--registry', default='iot-catalog-iot-schema-registry-dev',
                       help='Glue Schema Registry name')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--action', required=True, 
                       choices=['register-v1', 'register-v2', 'list-versions', 'check-compatibility'],
                       help='Action to perform')
    parser.add_argument('--schema-name', default='iot-device-telemetry',
                       help='Schema name')
    
    args = parser.parse_args()
    
    # Initialize manager
    manager = SchemaManager(registry_name=args.registry, region=args.region)
    
    if args.action == 'register-v1':
        schema_v1 = manager.get_schema_v1()
        manager.register_schema(args.schema_name, schema_v1)
    
    elif args.action == 'register-v2':
        schema_v2 = manager.get_schema_v2()
        manager.register_schema_version(args.schema_name, schema_v2)
    
    elif args.action == 'list-versions':
        manager.list_schema_versions(args.schema_name)
    
    elif args.action == 'check-compatibility':
        schema_v2 = manager.get_schema_v2()
        manager.check_schema_compatibility(args.schema_name, schema_v2)


if __name__ == "__main__":
    main()
