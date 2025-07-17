#!/bin/bash
#
# Manual Cron Job Installation for RAGFlow Backups
# Run this script to get the cron job commands to install manually
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify_backup.sh"

echo "RAGFlow Backup - Manual Cron Installation"
echo "========================================"
echo
echo "Since automatic cron installation requires sudo privileges,"
echo "please manually add these cron jobs to your crontab:"
echo
echo "1. Run: crontab -e"
echo "2. Add these lines to the end of the file:"
echo

cat << EOF

# RAGFlow Backup Automation
# Daily backup at 2:00 AM
0 2 * * * ${BACKUP_SCRIPT} >> /share/backups/ragflow/logs/cron.log 2>&1

# Daily backup verification at 3:00 AM  
0 3 * * * ${VERIFY_SCRIPT} --quick >> /share/backups/ragflow/logs/cron.log 2>&1

# Weekly detailed verification and report on Sundays at 4:00 AM
0 4 * * 0 ${VERIFY_SCRIPT} --all --report >> /share/backups/ragflow/logs/cron.log 2>&1

# Monthly cleanup and maintenance on 1st day at 5:00 AM
0 5 1 * * find /share/backups/ragflow/logs -name "*.log" -mtime +90 -delete >> /share/backups/ragflow/logs/cron.log 2>&1

EOF

echo
echo "3. Save and exit the editor"
echo "4. Verify with: crontab -l"
echo
echo "Alternative: Copy and run these commands:"
echo
echo "# Add jobs to existing crontab:"
echo "(crontab -l 2>/dev/null; cat << 'EOCRON'"
echo "# RAGFlow Backup Automation"
echo "0 2 * * * ${BACKUP_SCRIPT} >> /share/backups/ragflow/logs/cron.log 2>&1"
echo "0 3 * * * ${VERIFY_SCRIPT} --quick >> /share/backups/ragflow/logs/cron.log 2>&1"
echo "0 4 * * 0 ${VERIFY_SCRIPT} --all --report >> /share/backups/ragflow/logs/cron.log 2>&1"
echo "0 5 1 * * find /share/backups/ragflow/logs -name '*.log' -mtime +90 -delete >> /share/backups/ragflow/logs/cron.log 2>&1"
echo "EOCRON"
echo ") | crontab -"
echo
echo "Testing:"
echo "--------"
echo "Test backup: ${BACKUP_SCRIPT}"
echo "Check logs:  tail -f /share/backups/ragflow/logs/cron.log"
echo "Verify cron: crontab -l | grep RAGFlow"