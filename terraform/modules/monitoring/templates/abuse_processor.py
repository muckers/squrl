import json
import boto3
import os
from datetime import datetime, timedelta
from typing import Dict, List, Any
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
logs_client = boto3.client('logs')
cloudwatch = boto3.client('cloudwatch')
sns = boto3.client('sns')

# Environment variables
LOG_GROUP_NAME = os.environ['LOG_GROUP_NAME']
ENVIRONMENT = os.environ['ENVIRONMENT']
SERVICE_NAME = os.environ['SERVICE_NAME']
ABUSE_THRESHOLD = int(os.environ['ABUSE_THRESHOLD'])
ALERT_SNS_TOPIC_ARN = os.environ['ALERT_SNS_TOPIC_ARN']

def handler(event, context):
    """
    Lambda function to process logs and detect abuse patterns
    Runs every 5 minutes to analyze recent logs
    """
    try:
        logger.info(f"Starting abuse detection analysis for {SERVICE_NAME}-{ENVIRONMENT}")
        
        # Define time window (last 5 minutes)
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=5)
        
        # Analyze different abuse patterns
        results = {
            'high_volume_ips': analyze_high_volume_ips(start_time, end_time),
            'scanner_detection': analyze_scanner_behavior(start_time, end_time),
            'suspicious_patterns': analyze_suspicious_patterns(start_time, end_time)
        }
        
        # Send alerts if abuse detected
        alerts_sent = 0
        for pattern_type, detections in results.items():
            if detections:
                alerts_sent += send_abuse_alerts(pattern_type, detections)
                publish_metrics(pattern_type, len(detections))
        
        logger.info(f"Abuse detection completed. Alerts sent: {alerts_sent}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Abuse detection completed successfully',
                'results': results,
                'alerts_sent': alerts_sent
            })
        }
        
    except Exception as e:
        logger.error(f"Error in abuse detection: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }

def analyze_high_volume_ips(start_time: datetime, end_time: datetime) -> List[Dict[str, Any]]:
    """Analyze logs for IPs making excessive requests"""
    query = f'''
        fields @timestamp, source_ip
        | filter @timestamp >= "{start_time.isoformat()}" and @timestamp <= "{end_time.isoformat()}"
        | stats count() as request_count by source_ip
        | sort request_count desc
        | limit 100
    '''
    
    results = execute_log_query(query, start_time, end_time)
    high_volume_ips = []
    
    for result in results:
        request_count = int(result[1])  # Second field is request_count
        source_ip = result[0]  # First field is source_ip
        
        if request_count > ABUSE_THRESHOLD:
            high_volume_ips.append({
                'ip': source_ip,
                'request_count': request_count,
                'threshold_exceeded_by': request_count - ABUSE_THRESHOLD,
                'detection_type': 'high_volume'
            })
    
    return high_volume_ips

def analyze_scanner_behavior(start_time: datetime, end_time: datetime) -> List[Dict[str, Any]]:
    """Analyze logs for scanning behavior (high 404 rates)"""
    query = f'''
        fields @timestamp, source_ip, status_code
        | filter @timestamp >= "{start_time.isoformat()}" and @timestamp <= "{end_time.isoformat()}"
        | stats count() as total_requests, count() as error_requests by source_ip, status_code
        | filter status_code = "404"
        | sort error_requests desc
        | limit 50
    '''
    
    results = execute_log_query(query, start_time, end_time)
    scanners = []
    
    for result in results:
        if len(result) >= 3:
            source_ip = result[0]
            error_requests = int(result[1])
            total_requests = int(result[2])
            
            error_rate = (error_requests / total_requests) * 100 if total_requests > 0 else 0
            
            # Consider it scanning if >50% 404 rate and >10 requests
            if error_rate > 50 and total_requests > 10:
                scanners.append({
                    'ip': source_ip,
                    'total_requests': total_requests,
                    'error_requests': error_requests,
                    'error_rate': round(error_rate, 2),
                    'detection_type': 'scanner'
                })
    
    return scanners

def analyze_suspicious_patterns(start_time: datetime, end_time: datetime) -> List[Dict[str, Any]]:
    """Analyze logs for suspicious patterns like bot user agents"""
    query = f'''
        fields @timestamp, source_ip, user_agent, endpoint
        | filter @timestamp >= "{start_time.isoformat()}" and @timestamp <= "{end_time.isoformat()}"
        | filter user_agent like /bot|crawler|scanner|scraper/i
        | stats count() as suspicious_requests by source_ip, user_agent
        | sort suspicious_requests desc
        | limit 20
    '''
    
    results = execute_log_query(query, start_time, end_time)
    suspicious_patterns = []
    
    for result in results:
        if len(result) >= 3:
            source_ip = result[0]
            user_agent = result[1]
            suspicious_requests = int(result[2])
            
            if suspicious_requests > 5:  # More than 5 requests with bot-like user agent
                suspicious_patterns.append({
                    'ip': source_ip,
                    'user_agent': user_agent,
                    'suspicious_requests': suspicious_requests,
                    'detection_type': 'suspicious_user_agent'
                })
    
    return suspicious_patterns

def execute_log_query(query: str, start_time: datetime, end_time: datetime) -> List[List[str]]:
    """Execute CloudWatch Logs Insights query"""
    try:
        start_query_response = logs_client.start_query(
            logGroupName=LOG_GROUP_NAME,
            startTime=int(start_time.timestamp()),
            endTime=int(end_time.timestamp()),
            queryString=query
        )
        
        query_id = start_query_response['queryId']
        
        # Poll for query completion
        import time
        max_attempts = 30  # 30 seconds max wait
        attempts = 0
        
        while attempts < max_attempts:
            query_response = logs_client.get_query_results(queryId=query_id)
            status = query_response['status']
            
            if status == 'Complete':
                return query_response.get('results', [])
            elif status == 'Failed':
                logger.error(f"Log query failed: {query_response}")
                return []
            
            time.sleep(1)
            attempts += 1
        
        logger.warning(f"Query timed out: {query_id}")
        return []
        
    except Exception as e:
        logger.error(f"Error executing log query: {str(e)}")
        return []

def send_abuse_alerts(pattern_type: str, detections: List[Dict[str, Any]]) -> int:
    """Send SNS alerts for detected abuse patterns"""
    alerts_sent = 0
    
    try:
        # Group detections for efficient alerting
        if not detections:
            return 0
        
        # Create alert message
        alert_message = f"""
ABUSE DETECTION ALERT - {SERVICE_NAME.upper()} {ENVIRONMENT.upper()}

Pattern Type: {pattern_type.replace('_', ' ').title()}
Detections: {len(detections)}
Timestamp: {datetime.utcnow().isoformat()}

Top Offenders:
"""
        
        # Add top 5 offenders to alert
        for i, detection in enumerate(detections[:5]):
            alert_message += f"{i+1}. IP: {detection['ip']}"
            
            if 'request_count' in detection:
                alert_message += f" - Requests: {detection['request_count']}"
            if 'error_rate' in detection:
                alert_message += f" - Error Rate: {detection['error_rate']}%"
            if 'user_agent' in detection:
                alert_message += f" - User Agent: {detection['user_agent'][:100]}"
            
            alert_message += "\n"
        
        alert_message += f"\nTotal detections: {len(detections)}"
        alert_message += f"\nEnvironment: {ENVIRONMENT}"
        alert_message += f"\nService: {SERVICE_NAME}"
        
        # Send SNS notification
        sns.publish(
            TopicArn=ALERT_SNS_TOPIC_ARN,
            Subject=f"[{ENVIRONMENT.upper()}] {SERVICE_NAME} Abuse Detection Alert - {pattern_type}",
            Message=alert_message
        )
        
        alerts_sent = 1
        logger.info(f"Abuse alert sent for {pattern_type} with {len(detections)} detections")
        
    except Exception as e:
        logger.error(f"Error sending abuse alert: {str(e)}")
    
    return alerts_sent

def publish_metrics(pattern_type: str, detection_count: int):
    """Publish custom CloudWatch metrics"""
    try:
        cloudwatch.put_metric_data(
            Namespace=f'{SERVICE_NAME}/{ENVIRONMENT}/Security',
            MetricData=[
                {
                    'MetricName': f'AbuseDetections_{pattern_type}',
                    'Value': detection_count,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'Environment',
                            'Value': ENVIRONMENT
                        },
                        {
                            'Name': 'Service',
                            'Value': SERVICE_NAME
                        },
                        {
                            'Name': 'PatternType',
                            'Value': pattern_type
                        }
                    ]
                }
            ]
        )
        logger.info(f"Published metric for {pattern_type}: {detection_count} detections")
        
    except Exception as e:
        logger.error(f"Error publishing metrics: {str(e)}")