import json
import boto3
import os
import requests
import hashlib
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')

# Environment variables
DYNAMODB_TABLE_NAME = os.environ['DYNAMODB_TABLE_NAME']
ENVIRONMENT = os.environ['ENVIRONMENT']
SERVICE_NAME = os.environ['SERVICE_NAME']

# Get DynamoDB table
reputation_table = dynamodb.Table(DYNAMODB_TABLE_NAME)

def handler(event, context):
    """
    IP reputation checker Lambda function
    Checks IP addresses against known threat intelligence sources
    """
    try:
        logger.info(f"Processing IP reputation check: {json.dumps(event)}")
        
        # Extract IP address from event
        ip_address = event.get('ip_address')
        if not ip_address:
            return {'statusCode': 400, 'body': 'No IP address provided'}
        
        # Check cache first
        cached_result = get_cached_reputation(ip_address)
        if cached_result:
            logger.info(f"Found cached reputation for {ip_address}")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'ip_address': ip_address,
                    'reputation': cached_result,
                    'source': 'cache'
                })
            }
        
        # Perform reputation lookup
        reputation_data = perform_reputation_lookup(ip_address)
        
        # Cache the result
        cache_reputation(ip_address, reputation_data)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'ip_address': ip_address,
                'reputation': reputation_data,
                'source': 'lookup'
            })
        }
        
    except Exception as e:
        logger.error(f"Error in IP reputation check: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def get_cached_reputation(ip_address: str) -> Optional[Dict[str, Any]]:
    """Check DynamoDB cache for IP reputation data"""
    try:
        response = reputation_table.get_item(
            Key={'ip_address': ip_address}
        )
        
        if 'Item' in response:
            item = response['Item']
            # Check if cache entry is still valid (not expired)
            ttl = item.get('ttl', 0)
            if ttl > int(datetime.utcnow().timestamp()):
                return {
                    'is_malicious': item.get('is_malicious', False),
                    'threat_types': item.get('threat_types', []),
                    'confidence_score': item.get('confidence_score', 0),
                    'last_seen': item.get('last_seen'),
                    'sources': item.get('sources', []),
                    'cached_at': item.get('cached_at')
                }
        
        return None
        
    except Exception as e:
        logger.error(f"Error getting cached reputation: {str(e)}")
        return None

def perform_reputation_lookup(ip_address: str) -> Dict[str, Any]:
    """
    Perform IP reputation lookup using multiple sources
    This is a simplified implementation - in production you'd use commercial threat intelligence APIs
    """
    try:
        reputation_data = {
            'is_malicious': False,
            'threat_types': [],
            'confidence_score': 0,
            'last_seen': None,
            'sources': [],
            'lookup_timestamp': datetime.utcnow().isoformat()
        }
        
        # Check against basic heuristics (this is a simplified version)
        # In production, you'd integrate with services like:
        # - VirusTotal API
        # - AbuseIPDB API
        # - IBM X-Force
        # - Cisco Talos
        
        # Basic checks based on IP patterns
        reputation_data.update(check_ip_patterns(ip_address))
        
        # Check against known bad IP ranges (simplified)
        reputation_data.update(check_known_bad_ranges(ip_address))
        
        # Geolocation-based checks
        reputation_data.update(check_geolocation_risks(ip_address))
        
        logger.info(f"Completed reputation lookup for {ip_address}: {reputation_data}")
        return reputation_data
        
    except Exception as e:
        logger.error(f"Error performing reputation lookup: {str(e)}")
        # Return safe default
        return {
            'is_malicious': False,
            'threat_types': [],
            'confidence_score': 0,
            'last_seen': None,
            'sources': ['error'],
            'lookup_timestamp': datetime.utcnow().isoformat(),
            'error': str(e)
        }

def check_ip_patterns(ip_address: str) -> Dict[str, Any]:
    """Check IP address against known malicious patterns"""
    result = {'sources': ['pattern_check']}
    
    try:
        # Split IP into octets
        octets = ip_address.split('.')
        if len(octets) != 4:
            return result
        
        # Check for suspicious patterns
        suspicious_patterns = [
            # Private ranges being used publicly (simplified check)
            lambda o: o[0] == '10',  # Private class A
            lambda o: o[0] == '172' and 16 <= int(o[1]) <= 31,  # Private class B
            lambda o: o[0] == '192' and o[1] == '168',  # Private class C
            # Known cloud provider ranges that are often abused
            lambda o: o[0] == '1' and o[1] == '1' and o[2] == '1' and o[3] == '1',  # Cloudflare DNS
        ]
        
        for pattern in suspicious_patterns:
            try:
                if pattern(octets):
                    result['threat_types'] = result.get('threat_types', []) + ['suspicious_range']
                    result['confidence_score'] = max(result.get('confidence_score', 0), 30)
                    break
            except:
                continue
                
    except Exception as e:
        logger.error(f"Error in pattern check: {str(e)}")
    
    return result

def check_known_bad_ranges(ip_address: str) -> Dict[str, Any]:
    """
    Check against known bad IP ranges
    This is a simplified version - in production you'd have a comprehensive list
    """
    result = {'sources': ['bad_ranges_check']}
    
    try:
        # This would be replaced with actual threat intelligence feeds
        # For demo purposes, we'll just check some obvious cases
        
        # Known bad patterns (simplified)
        bad_patterns = [
            '0.0.0.0',  # Invalid
            '127.0.0.1',  # Localhost (shouldn't appear in web requests)
            '255.255.255.255',  # Broadcast
        ]
        
        if ip_address in bad_patterns:
            result['is_malicious'] = True
            result['threat_types'] = ['invalid_ip']
            result['confidence_score'] = 90
        
    except Exception as e:
        logger.error(f"Error in bad ranges check: {str(e)}")
    
    return result

def check_geolocation_risks(ip_address: str) -> Dict[str, Any]:
    """
    Check geolocation-based risk factors
    This is a simplified implementation
    """
    result = {'sources': ['geo_check']}
    
    try:
        # In production, you'd use a geolocation service
        # This is a placeholder that demonstrates the concept
        
        # You could check:
        # - Countries with high malware activity
        # - Regions known for bot activity
        # - VPN/Proxy detection
        # - Hosting provider detection
        
        # For now, just add a basic confidence score
        result['confidence_score'] = 10  # Low baseline confidence
        
    except Exception as e:
        logger.error(f"Error in geolocation check: {str(e)}")
    
    return result

def cache_reputation(ip_address: str, reputation_data: Dict[str, Any]):
    """Cache reputation data in DynamoDB"""
    try:
        # Set TTL (cache for 4 hours for reputation data)
        ttl = int((datetime.utcnow() + timedelta(hours=4)).timestamp())
        
        # Prepare item for DynamoDB
        item = {
            'ip_address': ip_address,
            'is_malicious': reputation_data.get('is_malicious', False),
            'threat_types': set(reputation_data.get('threat_types', [])),  # Convert to set for DynamoDB
            'confidence_score': reputation_data.get('confidence_score', 0),
            'last_seen': reputation_data.get('last_seen'),
            'sources': set(reputation_data.get('sources', [])),
            'cached_at': datetime.utcnow().isoformat(),
            'ttl': ttl
        }
        
        reputation_table.put_item(Item=item)
        logger.info(f"Cached reputation data for {ip_address}")
        
    except Exception as e:
        logger.error(f"Error caching reputation data: {str(e)}")

# Helper function to integrate with external APIs (example)
def query_external_api(ip_address: str, api_name: str, api_key: str = None) -> Dict[str, Any]:
    """
    Template for querying external reputation APIs
    This would be implemented for each specific API
    """
    try:
        # Example for VirusTotal API (would need API key)
        if api_name == 'virustotal' and api_key:
            headers = {
                'x-apikey': api_key
            }
            url = f'https://www.virustotal.com/api/v3/ip_addresses/{ip_address}'
            
            response = requests.get(url, headers=headers, timeout=10)
            if response.status_code == 200:
                data = response.json()
                # Parse VirusTotal response
                return parse_virustotal_response(data)
        
        # Example for AbuseIPDB (would need API key)
        elif api_name == 'abuseipdb' and api_key:
            headers = {
                'Key': api_key,
                'Accept': 'application/json'
            }
            params = {
                'ipAddress': ip_address,
                'maxAgeInDays': 90,
                'verbose': ''
            }
            url = 'https://api.abuseipdb.com/api/v2/check'
            
            response = requests.get(url, headers=headers, params=params, timeout=10)
            if response.status_code == 200:
                data = response.json()
                return parse_abuseipdb_response(data)
        
        return {}
        
    except Exception as e:
        logger.error(f"Error querying {api_name} API: {str(e)}")
        return {}

def parse_virustotal_response(data: Dict[str, Any]) -> Dict[str, Any]:
    """Parse VirusTotal API response"""
    try:
        attributes = data.get('data', {}).get('attributes', {})
        last_analysis_stats = attributes.get('last_analysis_stats', {})
        
        malicious_count = last_analysis_stats.get('malicious', 0)
        suspicious_count = last_analysis_stats.get('suspicious', 0)
        total_engines = sum(last_analysis_stats.values())
        
        is_malicious = malicious_count > 0 or suspicious_count > 2
        confidence_score = min(((malicious_count + suspicious_count) / total_engines) * 100, 100) if total_engines > 0 else 0
        
        return {
            'is_malicious': is_malicious,
            'confidence_score': confidence_score,
            'sources': ['virustotal'],
            'threat_types': ['malware'] if malicious_count > 0 else []
        }
        
    except Exception as e:
        logger.error(f"Error parsing VirusTotal response: {str(e)}")
        return {}

def parse_abuseipdb_response(data: Dict[str, Any]) -> Dict[str, Any]:
    """Parse AbuseIPDB API response"""
    try:
        abuse_data = data.get('data', {})
        abuse_confidence = abuse_data.get('abuseConfidencePercentage', 0)
        
        is_malicious = abuse_confidence > 25  # Threshold for considering IP malicious
        
        return {
            'is_malicious': is_malicious,
            'confidence_score': abuse_confidence,
            'sources': ['abuseipdb'],
            'threat_types': ['abuse'] if is_malicious else []
        }
        
    except Exception as e:
        logger.error(f"Error parsing AbuseIPDB response: {str(e)}")
        return {}