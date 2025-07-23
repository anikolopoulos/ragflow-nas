#!/bin/bash
#
# RAGFlow Simple Backup Script (without disk space checks)
# For testing when disk space detection fails
#

set -euo pipefail

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
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Simple pre-flight checks (no disk space check)
simple_preflight_checks() {
    log "INFO" "Starting simple pre-flight checks..."
    
    # Check if Docker is running
    if ! docker ps >/dev/null 2>&1; then
        log "ERROR" "Docker is not running or not accessible"
        exit 1
    fi
    
    # Check if RAGFlow containers are running
    local containers=("ragflow-nas" "ragflow-mysql" "ragflow-elasticsearch" "ragflow-minio-nas")
    for container in "${containers[@]}"; do
        if ! docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
            log "WARNING" "Container ${container} is not running"
        fi
    done
    
    log "SUCCESS" "Simple pre-flight checks completed"
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
    
    if docker exec ragflow-mysql mysqldump \
        --single-transaction \
        --routines \
        --triggers \
        --all-databases \
        -u root -p"${MYSQL_ROOT_PASSWORD}" 2>/dev/null | gzip > "$backup_file"; then
        
        local size=$(du -h "$backup_file" | cut -f1)
        log "SUCCESS" "MySQL backup completed: $backup_file ($size)"
    else
        log "ERROR" "MySQL backup failed"
        return 1
    fi
}

# Configuration backup
backup_config() {
    log "INFO" "Starting configuration backup..."
    
    local config_backup="${BACKUP_ROOT}/daily/${DATE}/config_${TIMESTAMP}.tar.gz"
    
    if tar -czf "$config_backup" \
        -C "$PROJECT_ROOT" \
        docker-compose.yml \
        .env.example \
        entrypoint-wrapper.sh \
        nginx-ragflow-fixed.conf \
        conf/ \
        scripts/ \
        *.md \
        *.json \
        *.js 2>/dev/null; then
        
        local size=$(du -h "$config_backup" | cut -f1)
        log "SUCCESS" "Configuration backup completed: $config_backup ($size)"
    else
        log "ERROR" "Configuration backup failed"
        return 1
    fi
}

# Main function
main() {
    local start_time=$(date +%s)
    
    log "INFO" "=== RAGFlow Simple Backup Started ==="
    log "INFO" "Timestamp: $TIMESTAMP"
    log "INFO" "Backup location: ${BACKUP_ROOT}/daily/${DATE}"
    
    simple_preflight_checks
    setup_directories
    
    backup_mysql
    backup_config
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "SUCCESS" "=== RAGFlow Simple Backup Completed ==="
    log "INFO" "Total time: ${duration} seconds"
    log "INFO" "Log file: $LOG_FILE"
    
    # Display summary
    echo
    echo "Simple Backup Summary:"
    echo "====================="
    du -sh "${BACKUP_ROOT}/daily/${DATE}"/* 2>/dev/null || echo "No backup files found"
}

main "$@"