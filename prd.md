# RAGFlow Backup System - Product Requirements Document

## Executive Summary

This document outlines the requirements and implementation details for a comprehensive backup system for the RAGFlow deployment on QNAP NAS. The system will ensure data integrity, enable disaster recovery, and maintain business continuity for the AI-powered document processing platform.

## Project Overview

### Purpose
Implement an automated, reliable backup solution for RAGFlow that protects all critical data components while minimizing storage overhead and recovery time.

### Scope
- MySQL database backups
- MinIO object storage synchronization
- Elasticsearch index snapshots
- Redis cache backups (optional)
- Configuration file versioning
- Automated backup scheduling
- Retention policy implementation
- Restore procedures

## Technical Requirements

### 1. Data Components to Backup

#### 1.1 MySQL Database
- **Data**: User accounts, API keys, knowledge bases, configurations
- **Size**: Variable, typically 100MB-10GB
- **Backup Method**: mysqldump with --single-transaction
- **Frequency**: Daily
- **Retention**: 7 daily, 4 weekly, 12 monthly

#### 1.2 MinIO Object Storage
- **Data**: Documents, PDFs, images, processed files
- **Size**: Variable, can be 10GB-1TB+
- **Backup Method**: MinIO Client (mc) mirror/sync
- **Frequency**: Daily incremental
- **Retention**: Full mirror + versioning

#### 1.3 Elasticsearch Indices
- **Data**: Document indexes, search data
- **Size**: Variable, typically 20-50% of document size
- **Backup Method**: Elasticsearch snapshot API
- **Frequency**: Daily
- **Retention**: 7 daily snapshots

#### 1.4 Configuration Files
- **Data**: docker-compose.yml, .env, nginx configs
- **Size**: <1MB
- **Backup Method**: tar archive
- **Frequency**: On change + daily
- **Retention**: All versions (via Git)

### 2. Backup Storage Architecture

```
/share/backups/ragflow/
├── daily/
│   ├── 2025-07-17/
│   │   ├── mysql_dump.sql.gz
│   │   ├── elasticsearch_snapshot/
│   │   ├── config_backup.tar.gz
│   │   └── backup.log
├── weekly/
│   └── 2025-W29/
├── monthly/
│   └── 2025-07/
├── minio_mirror/
│   └── [real-time mirror of MinIO data]
├── scripts/
│   ├── backup.sh
│   ├── restore.sh
│   └── verify_backup.sh
└── logs/
    └── backup_history.log
```

### 3. Backup Script Requirements

#### 3.1 Main Backup Script (`backup.sh`)
- **Pre-flight checks**: Verify services are running
- **MySQL backup**: Use docker exec with compression
- **MinIO sync**: Incremental sync with mc
- **Elasticsearch snapshot**: REST API calls
- **Config backup**: Archive all config files
- **Logging**: Detailed operation logs
- **Error handling**: Graceful failure with notifications
- **Retention management**: Automatic old backup cleanup

#### 3.2 Restore Script (`restore.sh`)
- **Interactive mode**: Guide user through restore options
- **Selective restore**: Choose specific components
- **Point-in-time recovery**: Select backup date
- **Verification**: Check data integrity after restore
- **Rollback capability**: Undo failed restore

### 4. QNAP-Specific Integration

#### 4.1 Storage Configuration
- Use separate storage pool/volume for backups
- Enable QNAP snapshots on Docker share
- Configure quota for backup storage

#### 4.2 Scheduling
- Use QNAP cron for backup scheduling
- Integrate with QNAP notification system
- Monitor via QNAP Resource Monitor

### 5. Implementation Timeline

#### Phase 1: Basic Backup (Week 1)
- [ ] Create directory structure
- [ ] Implement MySQL backup
- [ ] Implement config backup
- [ ] Basic backup script

#### Phase 2: Full Backup (Week 2)
- [ ] Add MinIO synchronization
- [ ] Add Elasticsearch snapshots
- [ ] Implement retention policies
- [ ] Create restore script

#### Phase 3: Automation (Week 3)
- [ ] Set up cron scheduling
- [ ] Add monitoring and alerts
- [ ] Create verification scripts
- [ ] Documentation completion

#### Phase 4: Testing (Week 4)
- [ ] Full backup/restore testing
- [ ] Performance optimization
- [ ] Disaster recovery drill
- [ ] Final documentation

## Success Criteria

### Functional Requirements
- ✓ All data components backed up successfully
- ✓ Automated daily backups without manual intervention
- ✓ Restore completes within 30 minutes
- ✓ No data loss during backup/restore
- ✓ Backup storage < 2x production data size

### Performance Requirements
- Backup completion < 1 hour
- Minimal impact on production (<10% CPU/RAM)
- Incremental backups < 15 minutes
- Backup verification < 5 minutes

### Reliability Requirements
- 99.9% backup success rate
- Automatic retry on failure
- Email/notification on backup status
- Monthly restore testing

## Monitoring and Maintenance

### Daily Monitoring
- Check backup completion status
- Verify backup sizes are reasonable
- Monitor available storage space

### Weekly Tasks
- Review backup logs for errors
- Verify weekly backup rotation
- Test random file restoration

### Monthly Tasks
- Full restore test to staging
- Backup storage cleanup
- Performance metrics review
- Update documentation

## Risk Mitigation

### Identified Risks
1. **Storage Full**: Implement alerts at 80% capacity
2. **Backup Corruption**: Daily verification checks
3. **Long Backup Duration**: Incremental backups, parallel processing
4. **Network Issues**: Local backup first, remote sync later
5. **Human Error**: Automated scripts, limited manual intervention

### Contingency Plans
- Secondary backup location (USB/Cloud)
- Manual backup procedures documented
- Rollback procedures for failed restores
- Contact list for emergency support

## Security Considerations

### Access Control
- Backup scripts run as restricted user
- Encrypted backup storage
- No passwords in scripts (use .env)
- Audit log for all backup operations

### Data Protection
- Compression for all backups
- Optional encryption for sensitive data
- Secure deletion of old backups
- Access logs for backup directories

## Testing Procedures

### Unit Tests
1. MySQL backup and restore
2. MinIO sync verification
3. Elasticsearch snapshot/restore
4. Configuration backup integrity

### Integration Tests
1. Full backup cycle
2. Complete system restore
3. Point-in-time recovery
4. Cross-component dependencies

### Disaster Recovery Test
- Quarterly full DR drill
- Document recovery time
- Identify improvement areas
- Update procedures based on findings

## Appendix

### A. Backup Command Examples

```bash
# MySQL Backup
docker exec ragflow-mysql mysqldump \
  --single-transaction \
  --routines \
  --triggers \
  -u root -p${MYSQL_ROOT_PASSWORD} \
  ai_lab_ragflow | gzip > mysql_backup.sql.gz

# MinIO Sync
docker run --rm \
  -v /share/backups/ragflow/minio_mirror:/backup \
  minio/mc mirror \
  ragflow-minio/ragflow /backup/

# Elasticsearch Snapshot
curl -X PUT "localhost:9201/_snapshot/backup/snapshot_$(date +%Y%m%d)" \
  -H 'Content-Type: application/json' \
  -d '{"indices": "*", "include_global_state": false}'
```

### B. Recovery Time Objectives

| Component | Backup Time | Restore Time | RPO | RTO |
|-----------|-------------|--------------|-----|-----|
| MySQL | 5-10 min | 10-15 min | 24h | 30 min |
| MinIO | 10-60 min | 20-120 min | 1h | 2h |
| Elasticsearch | 5-15 min | 10-20 min | 24h | 30 min |
| Configs | 1 min | 1 min | 24h | 5 min |

### C. Storage Estimates

Assuming:
- 100GB production data
- 10% daily change rate
- 30-day retention

Estimated backup storage:
- Daily backups: 7 × 10GB = 70GB
- Weekly backups: 4 × 100GB = 400GB  
- Monthly backups: 12 × 100GB = 1.2TB
- MinIO mirror: 100GB
- **Total: ~1.8TB**

## Approval and Sign-off

- **Author**: Claude (AI Assistant)
- **Date**: 2025-07-17
- **Version**: 1.0
- **Status**: Draft - Pending Review

---

*This document should be reviewed and updated quarterly or when significant changes occur to the RAGFlow deployment.*