#!/bin/bash
# QuantFlow 数据库备份脚本

set -e

BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/quantflow_$TIMESTAMP.sql.gz"
RETENTION_DAYS=7

echo "[$(date)] Starting backup..."

# 备份
pg_dump -h postgres -U quantflow quantflow | gzip > "$BACKUP_FILE"

echo "[$(date)] Backup saved: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"

# 清理旧备份
find "$BACKUP_DIR" -name "quantflow_*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "[$(date)] Cleanup: removed backups older than $RETENTION_DAYS days"
echo "[$(date)] Backup complete"
