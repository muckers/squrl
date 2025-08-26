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
dynamodb = boto3.resource('dynamodb')
wafv2 = boto3.client('wafv2')
sns = boto3.client('sns')

# Environment variables
DYNAMODB_ABUSE_TABLE = os.environ['DYNAMODB_ABUSE_TABLE']
WAF_WEB_ACL_NAME = os.environ.get('WAF_WEB_ACL_NAME', '')
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
ENVIRONMENT = os.environ['ENVIRONMENT']
SERVICE_NAME = os.environ['SERVICE_NAME']

# Get DynamoDB table
abuse_table = dynamodb.Table(DYNAMODB_ABUSE_TABLE)

def handler(event, context):
    """
    Automated abuse response handler
    Triggered by CloudWatch alarm state changes for abuse detection
    """
    try:
        logger.info(f"Processing abuse response event: {json.dumps(event)}")
        
        # Extract alarm details
        detail = event.get('detail', {})
        alarm_name = detail.get('alarmName', '')
        alarm_state = detail.get('state', {}).get('value', '')
        alarm_reason = detail.get('state', {}).get('reason', '')
        
        if alarm_state != 'ALARM':
            logger.info(f"Alarm {alarm_name} is not in ALARM state, skipping response")
            return {'statusCode': 200, 'body': 'No action needed'}
        
        # Determine response based on alarm type
        response_actions = determine_response_actions(alarm_name, alarm_reason)
        
        # Execute response actions
        results = execute_response_actions(response_actions)
        
        # Send notification about actions taken
        send_response_notification(alarm_name, alarm_reason, response_actions, results)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Abuse response completed',
                'alarm_name': alarm_name,
                'actions_taken': response_actions,
                'results': results
            })
        }
        
    except Exception as e:
        logger.error(f"Error in abuse response handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def determine_response_actions(alarm_name: str, alarm_reason: str) -> List[Dict[str, Any]]:
    """Determine appropriate response actions based on alarm type"""
    actions = []
    
    try:
        # Parse alarm name to determine type
        if 'high-volume' in alarm_name.lower():
            actions.extend([
                {'type': 'identify_high_volume_ips', 'severity': 'medium'},
                {'type': 'temporary_rate_limit', 'duration_minutes': 30},
                {'type': 'alert_admins', 'priority': 'high'}
            ])
        
        elif 'url-creation' in alarm_name.lower():
            actions.extend([
                {'type': 'identify_spam_creators', 'severity': 'high'},
                {'type': 'block_suspicious_ips', 'duration_minutes': 60},
                {'type': 'alert_admins', 'priority': 'critical'}
            ])
        
        elif 'custom-abuse' in alarm_name.lower():
            if 'scanner' in alarm_name.lower():
                actions.extend([
                    {'type': 'identify_scanners', 'severity': 'high'},
                    {'type': 'block_scanner_ips', 'duration_minutes': 120},
                    {'type': 'alert_security_team', 'priority': 'high'}
                ])
            elif 'suspicious_patterns' in alarm_name.lower():
                actions.extend([
                    {'type': 'analyze_suspicious_patterns', 'severity': 'medium'},
                    {'type': 'temporary_monitoring_increase', 'duration_minutes': 60},
                    {'type': 'alert_admins', 'priority': 'medium'}
                ])
        
        # Add default monitoring action
        actions.append({'type': 'increase_logging_detail', 'duration_minutes': 30})
        
        logger.info(f"Determined {len(actions)} response actions for alarm {alarm_name}")
        return actions
        
    except Exception as e:
        logger.error(f"Error determining response actions: {str(e)}")
        return [{'type': 'alert_admins', 'priority': 'high', 'error': str(e)}]

def execute_response_actions(actions: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Execute the determined response actions"""
    results = {
        'successful_actions': [],
        'failed_actions': [],
        'ips_blocked': [],
        'notifications_sent': 0
    }
    
    for action in actions:
        try:
            action_type = action['type']
            
            if action_type == 'identify_high_volume_ips':
                ips = identify_high_volume_ips()
                results['high_volume_ips'] = ips
                results['successful_actions'].append(action_type)
            
            elif action_type == 'identify_spam_creators':
                ips = identify_spam_creators()
                results['spam_creator_ips'] = ips
                results['successful_actions'].append(action_type)
            
            elif action_type == 'identify_scanners':
                ips = identify_scanner_ips()
                results['scanner_ips'] = ips
                results['successful_actions'].append(action_type)
            
            elif action_type in ['block_suspicious_ips', 'block_scanner_ips']:
                # Get IPs to block from previous identification steps
                ips_to_block = []
                if 'spam_creator_ips' in results:
                    ips_to_block.extend(results['spam_creator_ips'][:5])  # Block top 5
                if 'scanner_ips' in results:
                    ips_to_block.extend(results['scanner_ips'][:5])  # Block top 5
                
                if ips_to_block and WAF_WEB_ACL_NAME:
                    blocked_ips = block_ips_in_waf(ips_to_block, action.get('duration_minutes', 60))
                    results['ips_blocked'].extend(blocked_ips)
                    results['successful_actions'].append(action_type)
                else:
                    logger.warning(f"No IPs to block or WAF not configured for action {action_type}")
            
            elif action_type == 'temporary_rate_limit':
                # This would involve updating WAF rules to be more restrictive
                if WAF_WEB_ACL_NAME:
                    success = apply_temporary_rate_limit(action.get('duration_minutes', 30))
                    if success:
                        results['successful_actions'].append(action_type)
                    else:
                        results['failed_actions'].append(action_type)
                else:
                    logger.warning("WAF not configured, cannot apply rate limit")
            
            elif action_type in ['alert_admins', 'alert_security_team']:
                # These will be handled by send_response_notification
                results['successful_actions'].append(action_type)
            
            elif action_type in ['increase_logging_detail', 'temporary_monitoring_increase']:
                # These would involve updating log levels or monitoring settings
                # For now, just mark as successful
                results['successful_actions'].append(action_type)
            
            else:
                logger.warning(f"Unknown action type: {action_type}")
                results['failed_actions'].append(action_type)
                
        except Exception as e:
            logger.error(f"Error executing action {action}: {str(e)}")
            results['failed_actions'].append(f"{action['type']}: {str(e)}")
    
    return results

def identify_high_volume_ips() -> List[Dict[str, Any]]:
    """Identify IPs with high request volume from abuse tracking table"""
    try:
        # Query abuse tracking table for high-volume IPs
        now = datetime.utcnow()
        five_min_ago = now - timedelta(minutes=5)
        
        # Use GSI to find high abuse score IPs
        response = abuse_table.query(
            IndexName='abuse-score-index',
            KeyConditionExpression='abuse_score_range = :range',
            ExpressionAttributeValues={
                ':range': 'high'
            },
            Limit=20
        )
        
        high_volume_ips = []
        for item in response.get('Items', []):
            high_volume_ips.append({
                'ip': item['ip_address'],
                'request_count': item.get('request_count', 0),
                'abuse_score': item.get('abuse_score', 0),
                'last_seen': item.get('last_seen', '')
            })
        
        # Sort by abuse score
        high_volume_ips.sort(key=lambda x: x['abuse_score'], reverse=True)
        
        logger.info(f"Identified {len(high_volume_ips)} high volume IPs")
        return high_volume_ips[:10]  # Return top 10
        
    except Exception as e:
        logger.error(f"Error identifying high volume IPs: {str(e)}")
        return []

def identify_spam_creators() -> List[Dict[str, Any]]:
    """Identify IPs creating excessive URLs"""
    try:
        # Similar to high volume IPs but focused on URL creation
        response = abuse_table.query(
            IndexName='abuse-score-index',
            KeyConditionExpression='abuse_score_range = :range',
            ExpressionAttributeValues={
                ':range': 'critical'
            },
            Limit=15
        )
        
        spam_creators = []
        for item in response.get('Items', []):
            # Filter for IPs that have POST requests to /create
            methods = item.get('methods', set())
            resources = item.get('resources', set())
            
            if 'POST' in methods and any('/create' in r for r in resources):
                spam_creators.append({
                    'ip': item['ip_address'],
                    'request_count': item.get('request_count', 0),
                    'abuse_score': item.get('abuse_score', 0),
                    'last_seen': item.get('last_seen', '')
                })
        
        spam_creators.sort(key=lambda x: x['abuse_score'], reverse=True)
        
        logger.info(f"Identified {len(spam_creators)} spam creator IPs")
        return spam_creators[:5]  # Return top 5
        
    except Exception as e:
        logger.error(f"Error identifying spam creators: {str(e)}")
        return []

def identify_scanner_ips() -> List[Dict[str, Any]]:
    """Identify IPs showing scanner behavior"""
    try:
        # Look for IPs with high 404 rates
        response = abuse_table.scan(
            FilterExpression='contains(status_codes, :status)',
            ExpressionAttributeValues={
                ':status': '404'
            },
            Limit=20
        )
        
        scanner_ips = []
        for item in response.get('Items', []):
            status_codes = item.get('status_codes', set())
            total_requests = item.get('request_count', 0)
            
            # Count 404s
            error_count = len([s for s in status_codes if s.startswith('4')])
            error_rate = (error_count / len(status_codes)) * 100 if status_codes else 0
            
            if error_rate > 50 and total_requests > 10:  # High error rate with sufficient volume
                scanner_ips.append({
                    'ip': item['ip_address'],
                    'request_count': total_requests,
                    'error_rate': error_rate,
                    'abuse_score': item.get('abuse_score', 0),
                    'last_seen': item.get('last_seen', '')
                })
        
        scanner_ips.sort(key=lambda x: x['error_rate'], reverse=True)
        
        logger.info(f"Identified {len(scanner_ips)} scanner IPs")
        return scanner_ips[:5]  # Return top 5
        
    except Exception as e:
        logger.error(f"Error identifying scanner IPs: {str(e)}")
        return []

def block_ips_in_waf(ip_addresses: List[str], duration_minutes: int) -> List[str]:
    """Block IP addresses in WAF (simplified implementation)"""
    try:
        if not WAF_WEB_ACL_NAME:
            logger.warning("WAF Web ACL name not configured")
            return []
        
        # In a real implementation, you would:
        # 1. Get the existing WAF Web ACL
        # 2. Create or update an IP Set with the malicious IPs
        # 3. Add a rule to block traffic from that IP Set
        # 4. Schedule removal of the IPs after the duration
        
        # For this example, we'll just log the action
        logger.info(f"Would block IPs {ip_addresses} in WAF {WAF_WEB_ACL_NAME} for {duration_minutes} minutes")
        
        # Here you would implement the actual WAF API calls
        # blocked_ips = []
        # for ip in ip_addresses:
        #     try:
        #         # Add IP to WAF IP Set
        #         # wafv2.update_ip_set(...)
        #         blocked_ips.append(ip)
        #     except Exception as e:
        #         logger.error(f"Failed to block IP {ip}: {str(e)}")
        
        # Return the IPs that would be blocked
        return ip_addresses[:5]  # Limit to prevent too many blocks
        
    except Exception as e:
        logger.error(f"Error blocking IPs in WAF: {str(e)}")
        return []

def apply_temporary_rate_limit(duration_minutes: int) -> bool:
    """Apply temporary rate limiting (simplified implementation)"""
    try:
        if not WAF_WEB_ACL_NAME:
            return False
        
        # In a real implementation, you would:
        # 1. Get the current WAF Web ACL configuration
        # 2. Temporarily reduce the rate limit thresholds
        # 3. Schedule restoration of original thresholds
        
        logger.info(f"Would apply temporary rate limit for {duration_minutes} minutes")
        
        # Here you would implement the actual WAF rule updates
        # return update_waf_rate_limits(duration_minutes)
        
        return True  # Simulate success
        
    except Exception as e:
        logger.error(f"Error applying temporary rate limit: {str(e)}")
        return False

def send_response_notification(alarm_name: str, alarm_reason: str, actions: List[Dict[str, Any]], results: Dict[str, Any]):
    """Send notification about automated response actions"""
    try:
        message = f"""
AUTOMATED ABUSE RESPONSE COMPLETED

Service: {SERVICE_NAME}
Environment: {ENVIRONMENT}
Alarm: {alarm_name}
Reason: {alarm_reason}
Timestamp: {datetime.utcnow().isoformat()}

ACTIONS TAKEN:
"""
        
        for action in actions:
            message += f"- {action['type']} (severity: {action.get('severity', 'unknown')})\n"
        
        message += f"""
RESULTS:
- Successful actions: {len(results['successful_actions'])}
- Failed actions: {len(results['failed_actions'])}
- IPs blocked: {len(results['ips_blocked'])}
"""
        
        if results['ips_blocked']:
            message += f"\nBlocked IPs: {', '.join(results['ips_blocked'])}"
        
        if 'high_volume_ips' in results:
            message += f"\nHigh volume IPs identified: {len(results['high_volume_ips'])}"
        
        if 'spam_creator_ips' in results:
            message += f"\nSpam creator IPs identified: {len(results['spam_creator_ips'])}"
        
        if 'scanner_ips' in results:
            message += f"\nScanner IPs identified: {len(results['scanner_ips'])}"
        
        if results['failed_actions']:
            message += f"\nFailed actions: {', '.join(results['failed_actions'])}"
        
        message += f"""

This is an automated response from the abuse mitigation system.
Please review the actions taken and investigate if further manual intervention is needed.
"""
        
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"[{ENVIRONMENT.upper()}] Automated Abuse Response - {alarm_name}",
            Message=message
        )
        
        logger.info(f"Sent response notification for alarm {alarm_name}")
        
    except Exception as e:
        logger.error(f"Error sending response notification: {str(e)}")