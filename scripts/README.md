# RAGFlow Backup System

A comprehensive backup and disaster recovery solution for RAGFlow deployment on QNAP NAS.

## Overview

This backup system provides automated, reliable backup and restore capabilities for all RAGFlow components:
- MySQL database
- MinIO object storage
- Elasticsearch indices
- Configuration files

## Quick Start

### 1. Setup Backup System

```bash
# Run the setup script to configure everything
cd /share/docker/ragflow/scripts
./setup_backup_cron.sh
```

### 2. Run Your First Backup

```bash
# Manual backup
./backup.sh

# Verify the backup
./verify_backup.sh
```

### 3. View Available Backups

```bash
./verify_backup.sh --list
```

## Scripts Overview

### `backup.sh`
Main backup script that creates comprehensive backups of all RAGFlow components.

**Features:**
- MySQL database dump with compression
- MinIO object storage mirroring
- Elasticsearch snapshot creation
- Configuration file archiving
- Automatic retention management
- Detailed logging and reporting

**Usage:**
```bash
./backup.sh                    # Run full backup
```

### `restore.sh`
Interactive restore script for disaster recovery and selective component restoration.

**Features:**
- Interactive mode for guided restoration
- Selective component restoration
- Point-in-time recovery
- Backup verification before restore
- Safety confirmations

**Usage:**
```bash
./restore.sh                              # Interactive mode
./restore.sh --list                       # List available backups
./restore.sh --date 2025-07-17           # Restore from specific date
./restore.sh --date 2025-07-17 --component mysql --force  # Force restore MySQL only
```

### `verify_backup.sh`
Backup integrity verification and health reporting.

**Features:**
- Individual backup verification
- Bulk verification of all backups
- Detailed health reports
- Schedule compliance checking
- Corruption detection

**Usage:**
```bash
./verify_backup.sh                        # Verify latest backup
./verify_backup.sh --date 2025-07-17     # Verify specific backup
./verify_backup.sh --all --report        # Verify all backups with report
./verify_backup.sh --quick               # Quick verification only
```

### `setup_backup_cron.sh`
One-time setup script to configure the entire backup system.

**Features:**
- Directory structure creation
- Cron job installation
- Script deployment
- Monitoring setup
- Prerequisites checking

**Usage:**
```bash
./setup_backup_cron.sh                   # Full setup with cron
./setup_backup_cron.sh --no-cron        # Setup without cron jobs
./setup_backup_cron.sh --test           # Include script testing
```

## Backup Schedule

The automated backup system runs on the following schedule:

| Task | Schedule | Description |
|------|----------|-------------|
| Daily Backup | 02:00 AM | Full backup of all components |
| Daily Verification | 03:00 AM | Quick integrity check |
| Weekly Report | Sunday 04:00 AM | Detailed health report |
| Monthly Cleanup | 1st day 05:00 AM | Log cleanup and maintenance |

## Backup Storage Structure

```
/share/backups/ragflow/
├── daily/
│   ├── 2025-07-17/
│   │   ├── mysql_20250717_020015.sql.gz
│   │   ├── elasticsearch_snapshots/
│   │   ├── config_20250717_020030.tar.gz
│   │   └── backup_report_20250717_020045.txt
│   └── 2025-07-18/
├── weekly/
│   └── 2025-W29/
├── monthly/
│   └── 2025-07/
├── minio_mirror/
│   └── ragflow/
├── scripts/
│   ├── backup.sh
│   ├── restore.sh
│   └── verify_backup.sh
└── logs/
    ├── backup_20250717_020015.log
    └── cron.log
```

## Retention Policy

- **Daily backups**: 7 days
- **Weekly backups**: 4 weeks
- **Monthly backups**: 12 months
- **MinIO mirror**: Continuous sync
- **Log files**: 30 days

## Manual Operations

### Run Manual Backup
```bash
cd /share/docker/ragflow/scripts
./backup.sh
```

### Restore from Backup
```bash
# Interactive mode (recommended)
./restore.sh

# Restore specific component
./restore.sh --date 2025-07-17 --component mysql

# List available backups
./restore.sh --list
```

### Verify Backup Integrity
```bash
# Verify latest backup
./verify_backup.sh

# Verify all backups
./verify_backup.sh --all --report
```

### Monitor Backup Health
```bash
# Check recent backup status
./monitor_backups.sh

# View backup logs
tail -f /share/backups/ragflow/logs/cron.log
```

## Troubleshooting

### Common Issues

**1. Backup fails with "Docker not accessible"**
```bash
# Check if Docker is running
docker ps

# Check if user has Docker permissions
groups $USER | grep docker
```

**2. MySQL backup fails with "Access denied"**
```bash
# Verify MySQL credentials in .env file
cat /share/docker/ragflow/.env | grep MYSQL_ROOT_PASSWORD

# Test MySQL connection
docker exec ragflow-mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;"
```

**3. Insufficient disk space**
```bash
# Check available space
df -h /share/backups/ragflow

# Clean old backups manually
find /share/backups/ragflow/daily -type d -mtime +7 -exec rm -rf {} \;
```

**4. Cron jobs not running**
```bash
# Check if cron service is running
systemctl status cron

# Verify cron jobs are installed
crontab -l | grep RAGFlow

# Check cron logs
tail -f /var/log/cron
```

### Log Locations

- **Backup logs**: `/share/backups/ragflow/logs/backup_YYYYMMDD_HHMMSS.log`
- **Cron logs**: `/share/backups/ragflow/logs/cron.log`
- **Verification logs**: `/tmp/ragflow_verify_YYYYMMDD_HHMMSS.log`
- **Restore logs**: `/tmp/ragflow_restore_YYYYMMDD_HHMMSS.log`

### Getting Help

1. **Check script help**:
   ```bash
   ./backup.sh --help
   ./restore.sh --help
   ./verify_backup.sh --help
   ```

2. **View logs**:
   ```bash
   # Latest backup log
   ls -la /share/backups/ragflow/logs/backup_*.log | tail -1

   # Cron execution log
   tail -f /share/backups/ragflow/logs/cron.log
   ```

3. **Test backup system**:
   ```bash
   # Run verification on all backups
   ./verify_backup.sh --all --report

   # Generate health report
   ./verify_backup.sh --report
   ```

## Security Considerations

- All scripts use environment variables for credentials
- Backup files are stored with restricted permissions
- No passwords are logged or exposed in script output
- .env file is excluded from configuration backups

## Maintenance

### Monthly Tasks
- Review backup health reports
- Check disk space usage
- Test restore procedures
- Update backup retention if needed

### Quarterly Tasks
- Full disaster recovery test
- Review and update backup procedures
- Check for script updates
- Verify monitoring and alerting

## Support

For issues with the backup system:
1. Check the troubleshooting section above
2. Review the logs for error messages
3. Ensure all prerequisites are met
4. Test individual components (MySQL, MinIO, etc.)

---

*This backup system was generated by Claude Code for the RAGFlow NAS deployment.*