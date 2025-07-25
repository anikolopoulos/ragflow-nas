#!/bin/bash
#
# RAGFlow Backup Script
# Comprehensive backup solution for RAGFlow deployment on QNAP NAS
#
# Author: Generated by Claude Code
# Version: 1.0
# Date: $(date +%Y-%m-%d)
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_ROOT="/share/docker/backups/ragflow"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H%M%S)
TIMESTAMP="${DATE}_${TIME}"
LOG_FILE="${BACKUP_ROOT}/logs/backup_${TIMESTAMP}.log"

# Load environment variables
if [ -f "${PROJECT_ROOT}/.env" ]; then
    source "${PROJECT_ROOT}/.env"
else
    echo "Error: .env file not found at ${PROJECT_ROOT}/.env"
    exit 1
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create log directory if needed
    mkdir -p "$(dirname "$LOG_FILE")"
    
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
    
    case $level in
        "ERROR") echo -e "${RED}${message}${NC}" ;;
        "SUCCESS") echo -e "${GREEN}${message}${NC}" ;;
        "WARNING") echo -e "${YELLOW}${message}${NC}" ;;
        "INFO") echo -e "${BLUE}${message}${NC}" ;;
    esac
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Cleanup function
cleanup() {
    log "INFO" "Cleaning up temporary files..."
    # Add any cleanup tasks here
}

# Set up signal handlers
trap cleanup EXIT
trap 'error_exit "Script interrupted"' INT TERM

# Pre-flight checks
preflight_checks() {
    log "INFO" "Starting pre-flight checks..."
    
    # Check if Docker is running
    if ! docker ps >/dev/null 2>&1; then
        error_exit "Docker is not running or not accessible"
    fi
    
    # Check if RAGFlow containers are running
    local containers=("ragflow-nas" "ragflow-mysql" "ragflow-elasticsearch" "ragflow-minio-nas")
    for container in "${containers[@]}"; do
        if ! docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
            log "WARNING" "Container ${container} is not running"
        fi
    done
    
    # Check available disk space (require at least 2GB free)
    # Create backup directory if it doesn't exist
    mkdir -p "${BACKUP_ROOT}"
    
    # Get available space in KB, handle different df output formats
    local df_output=$(df "${BACKUP_ROOT}")
    local available_space=$(echo "$df_output" | awk 'END {print $4}')
    
    # Debug output
    log "INFO" "Disk space check for: ${BACKUP_ROOT}"
    log "INFO" "df output: $(echo "$df_output" | tail -1)"
    
    # Convert to GB for display (handle empty/invalid values)
    local available_gb=0
    if [[ "$available_space" =~ ^[0-9]+$ ]]; then
        available_gb=$((available_space / 1048576))
    else
        log "WARNING" "Could not parse disk space. Proceeding with backup..."
        log "SUCCESS" "Pre-flight checks completed"
        return 0
    fi
    
    if [ "$available_space" -lt 2097152 ]; then  # 2GB in KB
        error_exit "Insufficient disk space. At least 2GB required. Available: ${available_gb}GB"
    elif [ "$available_space" -lt 5242880 ]; then  # 5GB in KB
        log "WARNING" "Low disk space warning. Available: ${available_gb}GB. Consider freeing up space."
    else
        log "INFO" "Available disk space: ${available_gb}GB"
    fi
    
    log "SUCCESS" "Pre-flight checks completed"
}

# Create backup directories
setup_directories() {
    log "INFO" "Setting up backup directories..."
    
    local dirs=(
        "${BACKUP_ROOT}/daily/${DATE}"
        "${BACKUP_ROOT}/weekly"
        "${BACKUP_ROOT}/monthly"
        "${BACKUP_ROOT}/minio_mirror"
        "${BACKUP_ROOT}/scripts"
        "${BACKUP_ROOT}/logs"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    log "SUCCESS" "Backup directories created"
}

# MySQL backup
backup_mysql() {
    log "INFO" "Starting MySQL backup..."
    
    local backup_file="${BACKUP_ROOT}/daily/${DATE}/mysql_${TIMESTAMP}.sql.gz"
    
    # Create MySQL dump
    if docker exec ragflow-mysql mysqldump \
        --single-transaction \
        --routines \
        --triggers \
        --all-databases \
        -u root -p"${MYSQL_ROOT_PASSWORD}" 2>/dev/null | gzip > "$backup_file"; then
        
        local size=$(du -h "$backup_file" | cut -f1)
        log "SUCCESS" "MySQL backup completed: $backup_file ($size)"
    else
        error_exit "MySQL backup failed"
    fi
}

# MinIO backup
backup_minio() {
    log "INFO" "Starting MinIO backup..."
    
    local backup_dir="${BACKUP_ROOT}/minio_mirror"
    local temp_container="ragflow-minio-backup-$$"
    
    # Create temporary MinIO client container for backup
    docker run --rm \
        --name "$temp_container" \
        --network ragflow_ragflow-internal \
        -v "${backup_dir}:/backup" \
        --entrypoint sh \
        minio/mc:latest \
        -c "
            mc alias set source http://ragflow-minio-nas:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} &&
            mc mirror --overwrite source/ragflow /backup/ragflow/ || echo 'No data to backup'
        " 2>&1 | tee -a "$LOG_FILE"
    
    if [ -d "${backup_dir}/ragflow" ]; then
        local size=$(du -sh "$backup_dir" | cut -f1)
        log "SUCCESS" "MinIO backup completed: $backup_dir ($size)"
    else
        log "INFO" "MinIO bucket is empty or not accessible - skipping"
    fi
}

# Elasticsearch backup
backup_elasticsearch() {
    log "INFO" "Starting Elasticsearch backup..."
    
    local snapshot_name="snapshot_${TIMESTAMP}"
    local es_backup_dir="${BACKUP_ROOT}/daily/${DATE}/elasticsearch"
    
    # Check if Elasticsearch is accessible
    if ! curl -s "localhost:9201/_cluster/health" >/dev/null 2>&1; then
        log "INFO" "Elasticsearch not accessible on port 9201 - skipping"
        return 0
    fi
    
    # Create snapshot repository if it doesn't exist
    curl -s -X PUT "localhost:9201/_snapshot/backup" \
        -H 'Content-Type: application/json' \
        -d '{
            "type": "fs",
            "settings": {
                "location": "/tmp/elasticsearch_snapshots"
            }
        }' >/dev/null 2>&1
    
    # Create snapshot
    if curl -s -X PUT "localhost:9201/_snapshot/backup/${snapshot_name}" \
        -H 'Content-Type: application/json' \
        -d '{
            "indices": "*",
            "include_global_state": false,
            "metadata": {
                "taken_by": "ragflow_backup_script",
                "taken_because": "scheduled_backup"
            }
        }' | grep -q '"accepted":true'; then
        
        # Wait for snapshot to complete
        local max_wait=300  # 5 minutes
        local waited=0
        
        while [ $waited -lt $max_wait ]; do
            local status=$(curl -s "localhost:9201/_snapshot/backup/${snapshot_name}" | jq -r '.snapshots[0].state' 2>/dev/null)
            
            if [ "$status" = "SUCCESS" ]; then
                break
            elif [ "$status" = "FAILED" ]; then
                error_exit "Elasticsearch snapshot failed"
            fi
            
            sleep 10
            waited=$((waited + 10))
        done
        
        if [ $waited -ge $max_wait ]; then
            error_exit "Elasticsearch snapshot timed out"
        fi
        
        # Copy snapshot files from container
        mkdir -p "$es_backup_dir"
        if docker cp ragflow-elasticsearch:/tmp/elasticsearch_snapshots "$es_backup_dir/"; then
            log "SUCCESS" "Elasticsearch backup completed: $es_backup_dir"
        else
            log "WARNING" "Failed to copy Elasticsearch snapshot files"
        fi
    else
        log "WARNING" "Elasticsearch backup failed"
    fi
}

# Configuration backup
backup_config() {
    log "INFO" "Starting configuration backup..."
    
    local config_backup="${BACKUP_ROOT}/daily/${DATE}/config_${TIMESTAMP}.tar.gz"
    
    # Archive configuration files
    cd "$PROJECT_ROOT"
    local files_to_backup=""
    
    # Check for each file/directory and add if exists
    for item in docker-compose.yml .env.example entrypoint-wrapper.sh nginx-ragflow-fixed.conf; do
        [ -f "$item" ] && files_to_backup="$files_to_backup $item"
    done
    
    # Add directories if they exist
    [ -d "conf" ] && files_to_backup="$files_to_backup conf/"
    [ -d "scripts" ] && files_to_backup="$files_to_backup scripts/"
    
    # Add wildcard files
    files_to_backup="$files_to_backup *.md *.json *.js"
    
    if tar -czf "$config_backup" $files_to_backup 2>/dev/null; then
        
        local size=$(du -h "$config_backup" | cut -f1)
        log "SUCCESS" "Configuration backup completed: $config_backup ($size)"
    else
        error_exit "Configuration backup failed"
    fi
}

# Backup retention management
manage_retention() {
    log "INFO" "Managing backup retention..."
    
    # Daily backups - keep 7 days
    find "${BACKUP_ROOT}/daily" -type d -name "20*" -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
    
    # Weekly backups - keep 4 weeks (create weekly backup on Sundays)
    if [ "$(date +%u)" -eq 7 ]; then  # Sunday
        local week_num=$(date +%Y-W%U)
        local weekly_dir="${BACKUP_ROOT}/weekly/${week_num}"
        
        if [ ! -d "$weekly_dir" ]; then
            mkdir -p "$weekly_dir"
            cp -r "${BACKUP_ROOT}/daily/${DATE}"/* "$weekly_dir/"
            log "SUCCESS" "Weekly backup created: $weekly_dir"
        fi
    fi
    
    # Remove old weekly backups (keep 4)
    find "${BACKUP_ROOT}/weekly" -type d -name "20*" | sort | head -n -4 | xargs rm -rf 2>/dev/null || true
    
    # Monthly backups - keep 12 months (create monthly backup on 1st)
    if [ "$(date +%d)" -eq 01 ]; then  # First day of month
        local month=$(date +%Y-%m)
        local monthly_dir="${BACKUP_ROOT}/monthly/${month}"
        
        if [ ! -d "$monthly_dir" ]; then
            mkdir -p "$monthly_dir"
            cp -r "${BACKUP_ROOT}/daily/${DATE}"/* "$monthly_dir/"
            log "SUCCESS" "Monthly backup created: $monthly_dir"
        fi
    fi
    
    # Remove old monthly backups (keep 12)
    find "${BACKUP_ROOT}/monthly" -type d -name "20*" | sort | head -n -12 | xargs rm -rf 2>/dev/null || true
    
    # Clean old logs (keep 30 days)
    find "${BACKUP_ROOT}/logs" -name "backup_*.log" -mtime +30 -delete 2>/dev/null || true
    
    log "SUCCESS" "Retention management completed"
}

# Generate backup report
generate_report() {
    log "INFO" "Generating backup report..."
    
    local report_file="${BACKUP_ROOT}/daily/${DATE}/backup_report_${TIMESTAMP}.txt"
    
    cat > "$report_file" << EOF
RAGFlow Backup Report
=====================
Date: $(date)
Backup Location: ${BACKUP_ROOT}/daily/${DATE}

Backup Components:
$(ls -lh "${BACKUP_ROOT}/daily/${DATE}")

Disk Usage:
$(df -h "${BACKUP_ROOT}")

Container Status:
$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}")

Total Backup Size: $(du -sh "${BACKUP_ROOT}/daily/${DATE}" | cut -f1)

Log File: ${LOG_FILE}
EOF
    
    log "SUCCESS" "Backup report generated: $report_file"
}

# Main backup function
main() {
    local start_time=$(date +%s)
    
    log "INFO" "=== RAGFlow Backup Started ==="
    log "INFO" "Timestamp: $TIMESTAMP"
    log "INFO" "Backup location: ${BACKUP_ROOT}/daily/${DATE}"
    
    preflight_checks
    setup_directories
    
    backup_mysql
    backup_minio
    backup_elasticsearch
    backup_config
    
    manage_retention
    generate_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "SUCCESS" "=== RAGFlow Backup Completed ==="
    log "INFO" "Total time: ${duration} seconds"
    log "INFO" "Log file: $LOG_FILE"
    
    # Display summary
    echo
    echo "Backup Summary:"
    echo "==============="
    du -sh "${BACKUP_ROOT}/daily/${DATE}"/* 2>/dev/null || echo "No backup files found"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi