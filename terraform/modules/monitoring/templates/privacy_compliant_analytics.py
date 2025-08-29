import json
import boto3
import os
from datetime import datetime, timedelta
from typing import Dict, Any, List
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
ALERT_SNS_TOPIC_ARN = os.environ['ALERT_SNS_TOPIC_ARN']

def handler(event, context):
    """
    PRIVACY-COMPLIANT Analytics Processor
    
    This function processes logs to generate anonymous aggregate analytics:
    - Analyzes API Gateway logs without extracting IP addresses
    - Generates anonymous usage patterns and metrics
    - Provides operational insights without compromising user privacy
    - All metrics are aggregated and anonymous
    """
    try:
        logger.info("Starting privacy-compliant analytics processing")
        
        # Define time window for analysis (last 15 minutes)
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=15)
        
        # Run privacy-compliant log queries
        analytics_data = {}
        
        # Query 1: Anonymous request volume and success rates
        analytics_data['request_metrics'] = analyze_request_patterns(start_time, end_time)
        
        # Query 2: Anonymous performance metrics
        analytics_data['performance_metrics'] = analyze_performance_patterns(start_time, end_time)
        
        # Query 3: Anonymous error patterns
        analytics_data['error_metrics'] = analyze_error_patterns(start_time, end_time)
        
        # Query 4: Anonymous usage patterns
        analytics_data['usage_metrics'] = analyze_usage_patterns(start_time, end_time)
        
        # Publish all anonymous metrics to CloudWatch
        publish_analytics_metrics(analytics_data, end_time)
        
        # Check for anomalies in anonymous data
        anomalies = detect_anonymous_anomalies(analytics_data)
        if anomalies:
            send_anomaly_alert(anomalies, end_time)
        
        logger.info(f"Analytics processing completed. Metrics published: {len(analytics_data)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Privacy-compliant analytics processing completed',
                'metrics_categories': len(analytics_data),
                'anomalies_detected': len(anomalies),
                'privacy_compliant': True,
                'processing_window_minutes': 15
            })
        }
        
    except Exception as e:
        logger.error(f"Error in analytics processing: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def analyze_request_patterns(start_time: datetime, end_time: datetime) -> Dict[str, int]:
    """Analyze anonymous request patterns from logs"""
    try:
        # PRIVACY-COMPLIANT QUERY: Count requests by status code (no IP/user-agent)
        query = """
        fields @timestamp, @message
        | filter @timestamp >= "{start}" and @timestamp < "{end}"
        | parse @message /(?<method>\w+)\s+(?<resource>\S+)\s+HTTP\/1\.1"\s+(?<status>\d+)/
        | stats count() as request_count by status
        | sort request_count desc
        """.format(
            start=start_time.strftime('%Y-%m-%d %H:%M:%S'),
            end=end_time.strftime('%Y-%m-%d %H:%M:%S')
        )
        
        results = run_log_insights_query(query, start_time, end_time)
        
        metrics = {
            'total_requests': 0,
            'successful_requests_2xx': 0,
            'redirect_requests_3xx': 0,
            'client_error_requests_4xx': 0,
            'server_error_requests_5xx': 0
        }
        
        for result in results:
            if len(result) >= 2:
                status = result[0]['value']
                count = int(result[1]['value'])
                metrics['total_requests'] += count
                
                if status.startswith('2'):
                    metrics['successful_requests_2xx'] += count
                elif status.startswith('3'):
                    metrics['redirect_requests_3xx'] += count
                elif status.startswith('4'):
                    metrics['client_error_requests_4xx'] += count
                elif status.startswith('5'):
                    metrics['server_error_requests_5xx'] += count
        
        return metrics
        
    except Exception as e:
        logger.error(f"Error analyzing request patterns: {str(e)}")
        return {'error_count': 1}

def analyze_performance_patterns(start_time: datetime, end_time: datetime) -> Dict[str, float]:
    """Analyze anonymous performance metrics from logs"""
    try:
        # PRIVACY-COMPLIANT QUERY: Response time analysis (no user identification)
        query = """
        fields @timestamp, @message
        | filter @timestamp >= "{start}" and @timestamp < "{end}"
        | parse @message /responseTime=(?<response_time>\d+)/
        | filter ispresent(response_time)
        | stats count() as request_count, avg(response_time) as avg_response_time, 
                max(response_time) as max_response_time, min(response_time) as min_response_time
        """.format(
            start=start_time.strftime('%Y-%m-%d %H:%M:%S'),
            end=end_time.strftime('%Y-%m-%d %H:%M:%S')
        )
        
        results = run_log_insights_query(query, start_time, end_time)
        
        metrics = {
            'avg_response_time_ms': 0.0,
            'max_response_time_ms': 0.0,
            'min_response_time_ms': 0.0,
            'performance_sample_count': 0
        }
        
        if results and len(results[0]) >= 4:
            result = results[0]
            metrics['performance_sample_count'] = int(result[0]['value'])
            metrics['avg_response_time_ms'] = float(result[1]['value'])
            metrics['max_response_time_ms'] = float(result[2]['value'])
            metrics['min_response_time_ms'] = float(result[3]['value'])
        
        return metrics
        
    except Exception as e:
        logger.error(f"Error analyzing performance patterns: {str(e)}")
        return {'performance_error_count': 1}

def analyze_error_patterns(start_time: datetime, end_time: datetime) -> Dict[str, int]:
    """Analyze anonymous error patterns from logs"""
    try:
        # PRIVACY-COMPLIANT QUERY: Error analysis by endpoint (no user tracking)
        query = """
        fields @timestamp, @message
        | filter @timestamp >= "{start}" and @timestamp < "{end}"
        | parse @message /(?<method>\w+)\s+(?<resource>\S+)\s+HTTP\/1\.1"\s+(?<status>[4-5]\d+)/
        | filter ispresent(status)
        | stats count() as error_count by resource, status
        | sort error_count desc
        | limit 20
        """.format(
            start=start_time.strftime('%Y-%m-%d %H:%M:%S'),
            end=end_time.strftime('%Y-%m-%d %H:%M:%S')
        )
        
        results = run_log_insights_query(query, start_time, end_time)
        
        metrics = {
            'total_errors': 0,
            'not_found_404_errors': 0,
            'rate_limit_429_errors': 0,
            'server_5xx_errors': 0,
            'unique_error_endpoints': 0
        }
        
        error_endpoints = set()
        
        for result in results:
            if len(result) >= 3:
                resource = result[0]['value']
                status = result[1]['value']
                count = int(result[2]['value'])
                
                metrics['total_errors'] += count
                error_endpoints.add(resource)
                
                if status == '404':
                    metrics['not_found_404_errors'] += count
                elif status == '429':
                    metrics['rate_limit_429_errors'] += count
                elif status.startswith('5'):
                    metrics['server_5xx_errors'] += count
        
        metrics['unique_error_endpoints'] = len(error_endpoints)
        return metrics
        
    except Exception as e:
        logger.error(f"Error analyzing error patterns: {str(e)}")
        return {'error_analysis_error_count': 1}

def analyze_usage_patterns(start_time: datetime, end_time: datetime) -> Dict[str, int]:
    """Analyze anonymous usage patterns from logs"""
    try:
        # PRIVACY-COMPLIANT QUERY: Endpoint usage analysis (anonymous aggregates)
        query = """
        fields @timestamp, @message
        | filter @timestamp >= "{start}" and @timestamp < "{end}"
        | parse @message /(?<method>\w+)\s+(?<resource>\S+)\s+HTTP\/1\.1"\s+(?<status>\d+)/
        | filter ispresent(method) and ispresent(resource) and status like /^2/
        | stats count() as usage_count by method, resource
        | sort usage_count desc
        | limit 10
        """.format(
            start=start_time.strftime('%Y-%m-%d %H:%M:%S'),
            end=end_time.strftime('%Y-%m-%d %H:%M:%S')
        )
        
        results = run_log_insights_query(query, start_time, end_time)
        
        metrics = {
            'url_creation_requests': 0,
            'url_redirect_requests': 0,
            'stats_requests': 0,
            'health_check_requests': 0,
            'other_requests': 0
        }
        
        for result in results:
            if len(result) >= 3:
                method = result[0]['value']
                resource = result[1]['value']
                count = int(result[2]['value'])
                
                if method == 'POST' and resource == '/create':
                    metrics['url_creation_requests'] += count
                elif method == 'GET' and '/' in resource and len(resource.split('/')) == 2:
                    # Likely a short URL redirect
                    metrics['url_redirect_requests'] += count
                elif '/stats' in resource:
                    metrics['stats_requests'] += count
                elif '/health' in resource:
                    metrics['health_check_requests'] += count
                else:
                    metrics['other_requests'] += count
        
        return metrics
        
    except Exception as e:
        logger.error(f"Error analyzing usage patterns: {str(e)}")
        return {'usage_analysis_error_count': 1}

def run_log_insights_query(query: str, start_time: datetime, end_time: datetime) -> List[List[Dict]]:
    """Execute a CloudWatch Logs Insights query and return results"""
    try:
        # Use API Gateway log group - this should be parameterized based on your setup
        log_group = f'/aws/apigateway/{SERVICE_NAME}'  # Adjust this based on your log group naming
        
        response = logs_client.start_query(
            logGroupName=log_group,
            startTime=int(start_time.timestamp()),
            endTime=int(end_time.timestamp()),
            queryString=query
        )
        
        query_id = response['queryId']
        
        # Wait for query to complete (with timeout)
        max_wait_time = 30  # seconds
        wait_time = 0
        
        while wait_time < max_wait_time:
            result = logs_client.get_query_results(queryId=query_id)
            status = result['status']
            
            if status == 'Complete':
                return result.get('results', [])
            elif status in ['Failed', 'Cancelled']:
                logger.error(f"Log Insights query failed with status: {status}")
                return []
            
            # Wait before checking again
            import time
            time.sleep(1)
            wait_time += 1
        
        logger.warning("Log Insights query timed out")
        return []
        
    except Exception as e:
        logger.error(f"Error running log insights query: {str(e)}")
        return []

def publish_analytics_metrics(analytics_data: Dict[str, Dict], timestamp: datetime):
    """Publish anonymous analytics metrics to CloudWatch"""
    try:
        metric_data = []
        
        for category, metrics in analytics_data.items():
            for metric_name, value in metrics.items():
                if isinstance(value, (int, float)):
                    metric_data.append({
                        'MetricName': metric_name,
                        'Value': value,
                        'Unit': 'Count' if isinstance(value, int) else 'Milliseconds',
                        'Timestamp': timestamp,
                        'Dimensions': [
                            {'Name': 'Environment', 'Value': ENVIRONMENT},
                            {'Name': 'Service', 'Value': SERVICE_NAME},
                            {'Name': 'Category', 'Value': category}
                        ]
                    })
        
        # Publish metrics in batches
        for i in range(0, len(metric_data), 20):
            batch = metric_data[i:i+20]
            cloudwatch.put_metric_data(
                Namespace=f'{SERVICE_NAME}/{ENVIRONMENT}/Analytics',
                MetricData=batch
            )
        
        logger.info(f"Published {len(metric_data)} analytics metrics to CloudWatch")
        
    except Exception as e:
        logger.error(f"Error publishing analytics metrics: {str(e)}")

def detect_anonymous_anomalies(analytics_data: Dict[str, Dict]) -> List[Dict[str, Any]]:
    """Detect anomalies in anonymous aggregate data"""
    anomalies = []
    
    try:
        request_metrics = analytics_data.get('request_metrics', {})
        performance_metrics = analytics_data.get('performance_metrics', {})
        error_metrics = analytics_data.get('error_metrics', {})
        
        # Check for high error rates (anonymous aggregate)
        total_requests = request_metrics.get('total_requests', 0)
        if total_requests > 0:
            error_requests = request_metrics.get('client_error_requests_4xx', 0) + \
                           request_metrics.get('server_error_requests_5xx', 0)
            error_rate = (error_requests / total_requests) * 100
            
            if error_rate > 10:  # 10% error rate threshold
                anomalies.append({
                    'type': 'high_error_rate',
                    'severity': 'high',
                    'value': error_rate,
                    'threshold': 10,
                    'description': f'Anonymous aggregate error rate is {error_rate:.2f}%'
                })
        
        # Check for high response times
        avg_response_time = performance_metrics.get('avg_response_time_ms', 0)
        if avg_response_time > 2000:  # 2 second threshold
            anomalies.append({
                'type': 'high_response_time',
                'severity': 'medium',
                'value': avg_response_time,
                'threshold': 2000,
                'description': f'Average response time is {avg_response_time:.0f}ms'
            })
        
        # Check for unusual error patterns
        not_found_errors = error_metrics.get('not_found_404_errors', 0)
        if not_found_errors > 100:  # High 404 rate might indicate scanning
            anomalies.append({
                'type': 'high_not_found_errors',
                'severity': 'medium',
                'value': not_found_errors,
                'threshold': 100,
                'description': f'High number of 404 errors: {not_found_errors}'
            })
        
    except Exception as e:
        logger.error(f"Error detecting anomalies: {str(e)}")
    
    return anomalies

def send_anomaly_alert(anomalies: List[Dict[str, Any]], timestamp: datetime):
    """Send alert for detected anomalies in anonymous data"""
    try:
        high_severity_count = sum(1 for a in anomalies if a.get('severity') == 'high')
        medium_severity_count = sum(1 for a in anomalies if a.get('severity') == 'medium')
        
        message = f"""
PRIVACY-COMPLIANT ANALYTICS ANOMALY ALERT

Service: {SERVICE_NAME}
Environment: {ENVIRONMENT}
Timestamp: {timestamp.isoformat()}

Anomalies Detected: {len(anomalies)}
- High Severity: {high_severity_count}
- Medium Severity: {medium_severity_count}

Anomaly Details:
"""
        
        for anomaly in anomalies:
            message += f"""
- Type: {anomaly['type']}
  Severity: {anomaly['severity']}
  Current Value: {anomaly['value']}
  Threshold: {anomaly['threshold']}
  Description: {anomaly['description']}
"""
        
        message += f"""

NOTE: This alert is based on anonymous aggregate analytics only.
No personally identifiable information (PII) was collected or analyzed.

This is an automated privacy-compliant monitoring alert.
"""
        
        sns.publish(
            TopicArn=ALERT_SNS_TOPIC_ARN,
            Subject=f"[{ENVIRONMENT.upper()}] Privacy-Compliant Analytics Anomaly Alert",
            Message=message
        )
        
        logger.info(f"Sent anomaly alert for {len(anomalies)} anomalies")
        
    except Exception as e:
        logger.error(f"Error sending anomaly alert: {str(e)}")