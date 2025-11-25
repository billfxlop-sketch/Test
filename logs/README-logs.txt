MAUT PANEL PRO EDITION - LOGS DIRECTORY
Owner: @maut_coder
Powered by MAUT CODER

This directory contains all log files for the MAUT Panel Pro system.
Logs are automatically rotated and managed by the system.

================================================================================
LOG FILES DESCRIPTION
================================================================================

maut-install.log
- Installation and setup logs
- Package installation records
- Configuration setup details
- First-time installation information

maut-actions.log
- User actions and operations
- Account creation/deletion
- Service modifications
- Configuration changes
- Administrative activities

maut-error.log
- System errors and warnings
- Service failures
- Configuration errors
- Permission issues
- Critical system events

maut-monitor.log
- System monitoring data
- Service status checks
- Resource usage logs
- Auto-recovery actions
- Performance metrics

maut-speedtest.log
- Speedtest results
- Network performance data
- Connectivity test logs
- Bandwidth usage records

maut-update.log
- Update and upgrade logs
- Version change records
- Backup and restore operations
- Package update history

xray-access.log
- Xray service access logs
- Connection attempts
- User authentication
- Traffic statistics
- Protocol-specific logs

xray-error.log
- Xray service errors
- Configuration issues
- Connection failures
- Security-related events

================================================================================
LOG ROTATION POLICY
================================================================================

All log files are automatically rotated with the following policy:

- Maximum log file size: 10MB
- Keep 5 rotated log files
- Compress old log files (.gz)
- Rotate weekly for activity logs
- Rotate daily for error logs

Example rotated files:
  maut-actions.log.1
  maut-actions.log.2.gz
  maut-actions.log.3.gz

================================================================================
LOG FORMAT
================================================================================

Standard log format:
  YYYY-MM-DD HH:MM:SS - COMPONENT: Message

Example:
  2024-01-01 12:00:00 - SSH: Created user 'john_doe'
  2024-01-01 12:05:00 - ERROR: Failed to restart Xray service

Components:
  INSTALL   - Installation related
  SSH       - SSH user management
  VMESS     - VMESS protocol
  VLESS     - VLESS protocol  
  TROJAN    - Trojan protocol
  XRAY      - Xray core service
  BACKUP    - Backup operations
  MONITOR   - System monitoring
  UPDATE    - Update operations
  THEME     - Theme changes
  DOMAIN    - Domain management
  ERROR     - Error events

================================================================================
LOG LEVELS
================================================================================

DEBUG   - Detailed information for debugging
INFO    - General system information
WARNING - Potential issues that don't stop operation
ERROR   - Errors that affect functionality
CRITICAL - Critical errors that may stop the system

================================================================================
LOG MANAGEMENT
================================================================================

Viewing Logs:
  Use the panel interface or command line:
  tail -f /var/log/maut-panel/maut-actions.log

Clearing Logs:
  Use the panel interface or:
  echo "" > /var/log/maut-panel/maut-actions.log

Backup Logs:
  Logs are automatically backed up during system backups

Monitoring Logs:
  Set up log monitoring with:
  - Logwatch
  - Fail2ban
  - Custom monitoring scripts

================================================================================
SECURITY NOTES
================================================================================

- Log files may contain sensitive information
- Regularly review and secure log files
- Implement log rotation to prevent disk filling
- Monitor for suspicious activities in logs
- Consider remote logging for critical systems

================================================================================
TROUBLESHOOTING
================================================================================

Common log locations for troubleshooting:

Service Issues:
  /var/log/maut-panel/maut-error.log
  /var/log/xray/error.log

User Management:
  /var/log/maut-panel/maut-actions.log

Performance Issues:
  /var/log/maut-panel/maut-monitor.log

Installation Problems:
  /var/log/maut-panel/maut-install.log

================================================================================
CUSTOM LOGGING
================================================================================

To add custom logging in scripts:

#!/bin/bash
LOG_FILE="/var/log/maut-panel/maut-actions.log"
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - CUSTOM: $1" >> "$LOG_FILE"
}

# Usage:
log_action "Custom event occurred"

================================================================================
SUPPORT
================================================================================

For log-related issues or questions:
- Check this README file
- Use the panel's log viewer
- Contact support with relevant log excerpts

Remember: Proper logging is crucial for system maintenance and security!

Generated on: 2024-01-01
Panel Version: 2.1 Pro
