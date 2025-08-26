import json
import boto3
import os
from datetime import datetime, timedelta
from typing import Dict, Any
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')
sns = boto3.client('sns')
logs = boto3.client('logs')

# Environment variables
DYNAMODB_TABLE_NAME = os.environ['DYNAMODB_TABLE_NAME']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
ENVIRONMENT = os.environ['ENVIRONMENT']
SERVICE_NAME = os.environ['SERVICE_NAME']
ABUSE_THRESHOLD_5MIN = int(os.environ['ABUSE_THRESHOLD_5MIN'])
ABUSE_THRESHOLD_HOUR = int(os.environ['ABUSE_THRESHOLD_HOUR'])
URL_CREATION_THRESHOLD = int(os.environ['URL_CREATION_THRESHOLD'])

# Get DynamoDB table
abuse_table = dynamodb.Table(DYNAMODB_TABLE_NAME)

def handler(event, context):
    """
    Real-time abuse detection handler
    Triggered by EventBridge for suspicious API Gateway activities
    """
    try:
        logger.info(f"Processing abuse detection event: {json.dumps(event)}")
        
        # Extract event details
        source_ip = event.get('source_ip')
        status = event.get('status')
        timestamp = event.get('timestamp', datetime.utcnow().isoformat())
        user_agent = event.get('user_agent', '')
        method = event.get('method', '')
        resource = event.get('resource', '')
        
        if not source_ip:
            logger.warning("No source IP found in event")
            return {'statusCode': 400, 'body': 'No source IP provided'}
        
        # Analyze the request
        abuse_score = calculate_abuse_score(source_ip, status, user_agent, method, resource)
        
        # Update tracking data
        update_tracking_data(source_ip, abuse_score, timestamp, status, method, resource)
        
        # Check if IP should be flagged
        should_alert = check_abuse_thresholds(source_ip)
        
        if should_alert:
            send_abuse_alert(source_ip, abuse_score, {
                'status': status,
                'user_agent': user_agent,
                'method': method,
                'resource': resource,
                'timestamp': timestamp
            })
        
        # Publish metrics
        publish_abuse_metrics(source_ip, abuse_score, status)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Abuse detection completed',
                'source_ip': source_ip,
                'abuse_score': abuse_score,
                'alert_sent': should_alert
            })
        }
        
    except Exception as e:
        logger.error(f"Error in real-time abuse detection: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def calculate_abuse_score(source_ip: str, status: str, user_agent: str, method: str, resource: str) -> int:
    """Calculate abuse score based on request characteristics"""
    score = 0
    
    # Status code scoring
    if status.startswith('4'):
        score += 2  # Client errors
    if status == '404':
        score += 3  # Scanner behavior
    if status == '429':
        score += 5  # Rate limiting triggered
        
    # User agent analysis
    user_agent_lower = user_agent.lower()
    suspicious_agents = ['bot', 'crawler', 'spider', 'scraper', 'scanner']
    for agent in suspicious_agents:
        if agent in user_agent_lower:
            score += 4
            break
    
    # Empty or suspicious user agents
    if not user_agent or len(user_agent) < 10:
        score += 3
    
    # Method and resource analysis
    if method == 'POST' and resource == '/create':
        score += 1  # URL creation attempts
    if resource.startswith('/admin') or resource.startswith('/.'):
        score += 5  # Directory traversal attempts
        
    # Check for rapid sequential requests (would be implemented with rate tracking)
    # This is a simplified version - in practice, you'd track request timestamps
    
    return min(score, 100)  # Cap at 100

def update_tracking_data(source_ip: str, abuse_score: int, timestamp: str, status: str, method: str, resource: str):
    """Update DynamoDB with tracking data"""
    try:
        # Use 5-minute windows for tracking
        time_window = get_time_window(timestamp, 5)  # 5-minute window
        ttl = int((datetime.utcnow() + timedelta(hours=24)).timestamp())  # 24-hour TTL
        
        # Update 5-minute window data
        abuse_table.update_item(
            Key={
                'ip_address': source_ip,
                'time_window': time_window
            },
            UpdateExpression="""
                SET request_count = if_not_exists(request_count, :zero) + :one,
                    abuse_score = if_not_exists(abuse_score, :zero) + :score,
                    last_seen = :timestamp,
                    ttl = :ttl,
                    abuse_score_range = :score_range
                ADD status_codes :status_set
            """,
            ExpressionAttributeValues={
                ':zero': 0,
                ':one': 1,
                ':score': abuse_score,
                ':timestamp': timestamp,
                ':ttl': ttl,
                ':score_range': get_abuse_score_range(abuse_score),
                ':status_set': {status}
            }
        )
        
        # Also update hourly window for broader tracking
        hour_window = get_time_window(timestamp, 60)  # 60-minute window
        abuse_table.update_item(
            Key={
                'ip_address': source_ip,
                'time_window': hour_window
            },
            UpdateExpression="""
                SET request_count = if_not_exists(request_count, :zero) + :one,
                    abuse_score = if_not_exists(abuse_score, :zero) + :score,
                    last_seen = :timestamp,
                    ttl = :ttl,
                    abuse_score_range = :score_range
                ADD methods :method_set, resources :resource_set
            """,
            ExpressionAttributeValues={
                ':zero': 0,
                ':one': 1,
                ':score': abuse_score,
                ':timestamp': timestamp,
                ':ttl': ttl,
                ':score_range': get_abuse_score_range(abuse_score),
                ':method_set': {method},
                ':resource_set': {resource}
            }
        )
        
        logger.info(f"Updated tracking data for IP {source_ip} in windows {time_window}, {hour_window}")
        
    except Exception as e:
        logger.error(f"Error updating tracking data: {str(e)}")

def check_abuse_thresholds(source_ip: str) -> bool:
    """Check if IP has exceeded abuse thresholds"""
    try:
        now = datetime.utcnow()
        
        # Check 5-minute threshold
        five_min_window = get_time_window(now.isoformat(), 5)
        response = abuse_table.get_item(
            Key={
                'ip_address': source_ip,
                'time_window': five_min_window
            }
        )
        
        if 'Item' in response:
            five_min_requests = response['Item'].get('request_count', 0)
            five_min_abuse_score = response['Item'].get('abuse_score', 0)
            
            if five_min_requests > ABUSE_THRESHOLD_5MIN or five_min_abuse_score > 50:
                return True
        
        # Check hourly threshold
        hour_window = get_time_window(now.isoformat(), 60)
        response = abuse_table.get_item(
            Key={
                'ip_address': source_ip,
                'time_window': hour_window
            }
        )
        
        if 'Item' in response:
            hour_requests = response['Item'].get('request_count', 0)
            hour_abuse_score = response['Item'].get('abuse_score', 0)
            
            if hour_requests > ABUSE_THRESHOLD_HOUR or hour_abuse_score > 100:
                return True
        
        return False
        
    except Exception as e:
        logger.error(f"Error checking abuse thresholds: {str(e)}")
        return False

def send_abuse_alert(source_ip: str, abuse_score: int, details: Dict[str, Any]):
    """Send SNS alert for detected abuse"""
    try:
        message = f"""
REAL-TIME ABUSE DETECTION ALERT

Service: {SERVICE_NAME}
Environment: {ENVIRONMENT}
Source IP: {source_ip}
Abuse Score: {abuse_score}
Timestamp: {details.get('timestamp')}

Request Details:
- Status: {details.get('status')}
- Method: {details.get('method')}
- Resource: {details.get('resource')}
- User Agent: {details.get('user_agent', 'N/A')[:100]}

This is an automated alert from the real-time abuse detection system.
Please investigate this IP address for potential malicious activity.
"""
        
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"[{ENVIRONMENT.upper()}] Real-time Abuse Detection - {source_ip}",
            Message=message
        )
        
        logger.info(f"Sent abuse alert for IP {source_ip} with score {abuse_score}")
        
    except Exception as e:
        logger.error(f"Error sending abuse alert: {str(e)}")

def publish_abuse_metrics(source_ip: str, abuse_score: int, status: str):
    """Publish custom CloudWatch metrics"""
    try:
        cloudwatch.put_metric_data(
            Namespace=f'{SERVICE_NAME}/{ENVIRONMENT}/Security',
            MetricData=[
                {
                    'MetricName': 'AbuseScore',
                    'Value': abuse_score,
                    'Unit': 'None',
                    'Dimensions': [
                        {'Name': 'Environment', 'Value': ENVIRONMENT},
                        {'Name': 'Service', 'Value': SERVICE_NAME},
                        {'Name': 'SourceIP', 'Value': source_ip}
                    ]
                },
                {
                    'MetricName': 'SuspiciousRequests',
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {'Name': 'Environment', 'Value': ENVIRONMENT},
                        {'Name': 'Service', 'Value': SERVICE_NAME},
                        {'Name': 'Status', 'Value': status}
                    ]
                }
            ]
        )
        
    except Exception as e:
        logger.error(f"Error publishing metrics: {str(e)}")

def get_time_window(timestamp: str, window_minutes: int) -> str:
    """Get time window string for grouping requests"""
    try:
        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        # Round down to the nearest window
        minutes = (dt.minute // window_minutes) * window_minutes
        window_dt = dt.replace(minute=minutes, second=0, microsecond=0)
        return f"{window_dt.isoformat()}_{window_minutes}min"
    except:
        # Fallback to current time
        dt = datetime.utcnow()
        minutes = (dt.minute // window_minutes) * window_minutes
        window_dt = dt.replace(minute=minutes, second=0, microsecond=0)
        return f"{window_dt.isoformat()}_{window_minutes}min"

def get_abuse_score_range(score: int) -> str:
    """Get abuse score range for GSI"""
    if score < 10:
        return "low"
    elif score < 30:
        return "medium"
    elif score < 60:
        return "high"
    else:
        return "critical"