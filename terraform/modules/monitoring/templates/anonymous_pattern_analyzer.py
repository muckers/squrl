import json
import boto3
import os
from datetime import datetime, timedelta
from typing import Dict, Any
import logging
import hashlib

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')
sns = boto3.client('sns')

# Environment variables
CLOUDWATCH_LOG_GROUP = os.environ['CLOUDWATCH_LOG_GROUP']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
ENVIRONMENT = os.environ['ENVIRONMENT']
SERVICE_NAME = os.environ['SERVICE_NAME']
ERROR_RATE_THRESHOLD = float(os.environ.get('ERROR_RATE_THRESHOLD', 5.0))

def handler(event, context):
    """
    PRIVACY-COMPLIANT Anonymous Pattern Analyzer
    
    This function analyzes aggregate patterns without collecting or storing any PII:
    - No IP addresses are collected or stored
    - No user-agent strings are collected
    - No individual user tracking
    - Only anonymous aggregate metrics are generated
    """
    try:
        logger.info(f"Processing anonymous pattern analysis: {json.dumps(sanitize_event(event))}")
        
        # Extract non-PII event details only
        status = event.get('status')
        timestamp = event.get('timestamp', datetime.utcnow().isoformat())
        method = event.get('method', '')
        resource = event.get('resource', '')
        
        if not status:
            logger.warning("No status code found in event")
            return {'statusCode': 400, 'body': 'No status code provided'}
        
        # Analyze anonymous patterns
        pattern_metrics = analyze_anonymous_patterns(status, method, resource, timestamp)
        
        # Publish anonymous aggregate metrics to CloudWatch
        publish_anonymous_metrics(pattern_metrics, timestamp)
        
        # Check if aggregate thresholds require alerting
        should_alert = check_anonymous_thresholds(pattern_metrics)
        
        if should_alert:
            send_anonymous_alert(pattern_metrics, timestamp)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Anonymous pattern analysis completed',
                'metrics_published': len(pattern_metrics),
                'alert_sent': should_alert,
                'privacy_compliant': True
            })
        }
        
    except Exception as e:
        logger.error(f"Error in anonymous pattern analysis: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def sanitize_event(event: Dict[str, Any]) -> Dict[str, Any]:
    """Remove any potential PII from event for logging"""
    sanitized = {}
    allowed_fields = ['status', 'method', 'resource', 'timestamp', 'environment', 'service']
    
    for field in allowed_fields:
        if field in event:
            sanitized[field] = event[field]
    
    return sanitized

def analyze_anonymous_patterns(status: str, method: str, resource: str, timestamp: str) -> Dict[str, Any]:
    """Analyze patterns using only anonymous aggregate data"""
    patterns = {}
    
    # HTTP status code analysis (anonymous)
    if status.startswith('4'):
        patterns['client_errors'] = 1
        if status == '404':
            patterns['not_found_requests'] = 1
        elif status == '429':
            patterns['rate_limited_requests'] = 1
    elif status.startswith('5'):
        patterns['server_errors'] = 1
    elif status.startswith('2'):
        patterns['successful_requests'] = 1
    
    # HTTP method analysis (anonymous)
    if method == 'POST':
        patterns['write_operations'] = 1
        if resource == '/create':
            patterns['url_creation_requests'] = 1
    elif method == 'GET':
        patterns['read_operations'] = 1
    
    # Resource pattern analysis (anonymous)
    if resource.startswith('/stats'):
        patterns['analytics_requests'] = 1
    elif resource == '/health':
        patterns['health_check_requests'] = 1
    
    # Time-based patterns (anonymous aggregate only)
    try:
        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        hour = dt.hour
        
        # Aggregate time-based patterns
        if 0 <= hour < 6:
            patterns['night_requests'] = 1
        elif 6 <= hour < 12:
            patterns['morning_requests'] = 1
        elif 12 <= hour < 18:
            patterns['afternoon_requests'] = 1
        else:
            patterns['evening_requests'] = 1
    except:
        patterns['unknown_time_requests'] = 1
    
    return patterns

def publish_anonymous_metrics(patterns: Dict[str, Any], timestamp: str):
    """Publish anonymous aggregate metrics to CloudWatch"""
    try:
        metric_data = []
        
        for metric_name, value in patterns.items():
            metric_data.append({
                'MetricName': metric_name,
                'Value': value,
                'Unit': 'Count',
                'Timestamp': timestamp,
                'Dimensions': [
                    {'Name': 'Environment', 'Value': ENVIRONMENT},
                    {'Name': 'Service', 'Value': SERVICE_NAME},
                    {'Name': 'Type', 'Value': 'anonymous-pattern'}
                ]
            })
        
        if metric_data:
            # Send metrics in batches of 20 (CloudWatch limit)
            for i in range(0, len(metric_data), 20):
                batch = metric_data[i:i+20]
                cloudwatch.put_metric_data(
                    Namespace=f'{SERVICE_NAME}/{ENVIRONMENT}/Analytics',
                    MetricData=batch
                )
            
            logger.info(f"Published {len(metric_data)} anonymous metrics to CloudWatch")
        
    except Exception as e:
        logger.error(f"Error publishing anonymous metrics: {str(e)}")

def check_anonymous_thresholds(patterns: Dict[str, Any]) -> bool:
    """Check if anonymous aggregate patterns exceed alert thresholds"""
    try:
        # Check for high error rates (anonymous aggregate)
        total_requests = sum(patterns.get(key, 0) for key in [
            'client_errors', 'server_errors', 'successful_requests'
        ])
        
        if total_requests > 0:
            error_requests = patterns.get('client_errors', 0) + patterns.get('server_errors', 0)
            error_rate = (error_requests / total_requests) * 100
            
            if error_rate > ERROR_RATE_THRESHOLD:
                logger.warning(f"High anonymous error rate detected: {error_rate:.2f}%")
                return True
        
        # Check for unusual patterns
        if patterns.get('server_errors', 0) > 10:
            logger.warning("High server error count detected in anonymous patterns")
            return True
        
        return False
        
    except Exception as e:
        logger.error(f"Error checking anonymous thresholds: {str(e)}")
        return False

def send_anonymous_alert(patterns: Dict[str, Any], timestamp: str):
    """Send alert for anonymous aggregate pattern anomalies"""
    try:
        # Create anonymous alert message (no PII)
        total_errors = patterns.get('client_errors', 0) + patterns.get('server_errors', 0)
        total_requests = sum(patterns.get(key, 0) for key in [
            'client_errors', 'server_errors', 'successful_requests'
        ])
        
        message = f"""
ANONYMOUS PATTERN ANALYSIS ALERT

Service: {SERVICE_NAME}
Environment: {ENVIRONMENT}
Timestamp: {timestamp}

Anonymous Aggregate Metrics:
- Total Requests: {total_requests}
- Error Requests: {total_errors}
- Error Rate: {(total_errors/total_requests*100) if total_requests > 0 else 0:.2f}%
- URL Creations: {patterns.get('url_creation_requests', 0)}
- Rate Limited: {patterns.get('rate_limited_requests', 0)}

NOTE: This alert is based on anonymous aggregate patterns only.
No personally identifiable information (PII) was collected or analyzed.

This is an automated privacy-compliant monitoring alert.
"""
        
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"[{ENVIRONMENT.upper()}] Anonymous Pattern Analysis Alert",
            Message=message
        )
        
        logger.info("Sent anonymous pattern analysis alert")
        
    except Exception as e:
        logger.error(f"Error sending anonymous alert: {str(e)}")

def get_anonymous_hash(value: str, salt: str = None) -> str:
    """
    Generate anonymous hash for aggregation without storing original values
    Used for privacy-compliant pattern detection
    """
    if salt is None:
        salt = os.environ.get('HASH_SALT', f"{SERVICE_NAME}-{ENVIRONMENT}")
    
    return hashlib.sha256(f"{value}-{salt}".encode()).hexdigest()[:16]

# Additional utility functions for anonymous pattern analysis

def analyze_resource_patterns(resource: str) -> Dict[str, int]:
    """Analyze resource access patterns without storing actual resource paths"""
    patterns = {}
    
    # Categorize resources anonymously
    if resource.startswith('/api/'):
        patterns['api_requests'] = 1
    elif resource.startswith('/stats'):
        patterns['stats_requests'] = 1
    elif resource.startswith('/health'):
        patterns['health_requests'] = 1
    elif resource == '/':
        patterns['root_requests'] = 1
    else:
        patterns['other_requests'] = 1
    
    return patterns

def analyze_temporal_patterns(timestamp: str) -> Dict[str, int]:
    """Analyze temporal patterns for anomaly detection"""
    patterns = {}
    
    try:
        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        
        # Day of week pattern (anonymous)
        day_of_week = dt.weekday()  # 0=Monday, 6=Sunday
        if day_of_week < 5:  # Monday-Friday
            patterns['weekday_requests'] = 1
        else:  # Saturday-Sunday
            patterns['weekend_requests'] = 1
        
        # Time of day patterns (anonymous aggregates)
        minute_of_day = dt.hour * 60 + dt.minute
        if 360 <= minute_of_day < 1080:  # 6 AM to 6 PM
            patterns['business_hours_requests'] = 1
        else:
            patterns['off_hours_requests'] = 1
            
    except Exception as e:
        logger.error(f"Error analyzing temporal patterns: {str(e)}")
        patterns['timestamp_parse_errors'] = 1
    
    return patterns