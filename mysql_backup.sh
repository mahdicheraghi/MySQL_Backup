#!/bin/bash
set -eo pipefail

# --------------------------
# Configurable Variables
# --------------------------
# MySQL Configuration
DB_HOST="localhost"
DB_PORT="3306"
DB_USER="root"
DB_PASS="your_db_password"
DATABASES=("db1" "db2")  # Databases to backup

# Backup Configuration
BACKUP_ROOT="/path/to/backups"
DAILY_DIR="$BACKUP_ROOT/daily"
WEEKLY_DIR="$BACKUP_ROOT/weekly"
MONTHLY_DIR="$BACKUP_ROOT/monthly"
GZIP_THREADS=4
LOG_FILE="/var/log/mysql_backup.log"

# SSH Configuration
REMOTE_ENABLE=false
REMOTE_HOST="remote.example.com"
REMOTE_USER="user"
REMOTE_PASS="your_ssh_password"
REMOTE_DIR="/remote/backup/path"
REMOTE_PORT="22"

# Retention Policies
DAILY_RETENTION_DAYS=7
WEEKLY_RETENTION_DAYS=28
MONTHLY_RETENTION_DAYS=365

# Progress Tracking
TOTAL_STEPS=5
CURRENT_STEP=1

# --------------------------
# Helper Functions
# --------------------------
log() {
    # Log messages with timestamp to file and stdout
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    # Handle critical errors and exit
    log "ERROR: $1"
    exit 1
}

show_progress() {
    # Display progress messages without newline characters
    local step=$1
    local message=$2
    printf "\rProgress: [%d/%d] %s" "$step" "$TOTAL_STEPS" "$message" >&2
}

check_prerequisites() {
    # Verify required tools are installed
    show_progress $CURRENT_STEP "Checking prerequisites"
    
    declare -a required_tools=("mysqldump" "pigz" "sshpass" "pv")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log "Missing required tool: $tool"
            echo "Installation commands:"
            echo "  Debian/Ubuntu: sudo apt-get install mysql-client pigz sshpass pv"
            echo "  RHEL/CentOS:   sudo yum install mysql pigz sshpass pv"
            error_exit "Dependency check failed"
        fi
    done
    
    ((CURRENT_STEP++))
}

# --------------------------
# Backup Function
# --------------------------
perform_backup() {
    local db=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_base="${db}_${timestamp}"
    local tmp_dir=$(mktemp -d)
    
    show_progress $CURRENT_STEP "Backing up $db database"
    
    # Perform database dump with transaction safety
    { mysqldump --single-transaction \
        -h "$DB_HOST" \
        -P "$DB_PORT" \
        -u "$DB_USER" \
        -p"$DB_PASS" \
        "$db" \
        | pv -N "Dumping $db" -petr \
        | pigz -9 -p $GZIP_THREADS > "${tmp_dir}/${backup_base}.sql.gz"; } || {
            rm -rf "$tmp_dir"
            error_exit "Failed to backup database $db"
        }

    # Generate SHA1 checksum
    show_progress $((CURRENT_STEP+1)) "Generating checksum"
    sha1sum "${tmp_dir}/${backup_base}.sql.gz" | awk '{print $1}' > "${tmp_dir}/${backup_base}.sha1"

    # Create final archive
    show_progress $((CURRENT_STEP+2)) "Creating final package"
    tar cf "${backup_base}.tar" -C "$tmp_dir" "${backup_base}.sql.gz" "${backup_base}.sha1" || {
        rm -rf "$tmp_dir"
        error_exit "Tar creation failed"
    }

    # Cleanup temporary files
    rm -rf "$tmp_dir"
    ((CURRENT_STEP+=3))
    
    # Output sanitized filename
    echo "$backup_base.tar" | tr -d '\r'
}

# --------------------------
# Retention Management
# --------------------------
manage_retention() {
    # Apply retention policies to backup directories
    show_progress $CURRENT_STEP "Applying retention policies"
    
    # Clean old daily backups
    find "$DAILY_DIR" -type f -name "*.tar" -mtime +$DAILY_RETENTION_DAYS -delete
    
    # Clean old weekly backups
    find "$WEEKLY_DIR" -type f -name "*.tar" -mtime +$WEEKLY_RETENTION_DAYS -delete
    
    # Clean old monthly backups
    find "$MONTHLY_DIR" -type f -name "*.tar" -mtime +$MONTHLY_RETENTION_DAYS -delete
    
    ((CURRENT_STEP++))
}

# --------------------------
# Main Execution Flow
# --------------------------
{
    # Initial setup
    check_prerequisites
    mkdir -p {$DAILY_DIR,$WEEKLY_DIR,$MONTHLY_DIR}

    # Process each database
    for db in "${DATABASES[@]}"; do
        log "Starting backup for database: $db"
        backup_file=$(perform_backup "$db")
        final_path="$DAILY_DIR/$backup_file"
        
        # Move backup to daily directory
        mv "$backup_file" "$final_path"

        # Determine backup type
        backup_date=$(date -d "$(echo "$backup_file" | grep -oE '[0-9]{8}')" +%s)
        
        # Weekly backup (every Wednesday)
        if [ $(date -d @$backup_date +%u) -eq 3 ]; then
            cp "$final_path" "$WEEKLY_DIR/"
        fi
        
        # Monthly backup (first day of month)
        if [ $(date -d @$backup_date +%d) -eq 01 ]; then
            cp "$final_path" "$MONTHLY_DIR/"
        fi

        # Remote transfer if enabled
        if $REMOTE_ENABLE; then
            show_progress $CURRENT_STEP "Transferring to remote"
            sshpass -p "$REMOTE_PASS" scp -P "$REMOTE_PORT" "$final_path" \
            "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" || log "Remote transfer failed for $backup_file"
        fi
    done

    # Cleanup old backups
    manage_retention
    echo -e "\nBackup completed successfully"
} | tee -a "$LOG_FILE"
