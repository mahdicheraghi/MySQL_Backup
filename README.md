# MySQL Backup Automation Script

[![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Open Source](https://img.shields.io/badge/Open%20Source-Yes-brightgreen)](https://opensource.org/)
[![Shell Check](https://img.shields.io/badge/Shell_Check-Validated-brightgreen)](https://github.com/koalaman/shellcheck)

Enterprise-grade MySQL database backup solution with intelligent retention policies and parallel processing.

## Key Features ✨

- **Multi-Database Support** - Backup individual databases
- **Smart Retention Policies**  
  📅 Daily (7 days)  
  📆 Weekly (4 weeks)  
  📅 Monthly (12 months)
- **Parallel Compression** - Multi-core GZIP via `pigz`
- **Progress Tracking** - Real-time monitoring with `pv`
- **SSH File Transfer** - Encrypted remote backups
- **Checksum Verification** - SHA1 integrity checks
- **Cross-Platform** - Supports Debian, Ubuntu, RHEL, CentOS
- **Transactional Backups** - Uses `--single-transaction` for InnoDB

## Installation ⚙️

### Prerequisites

```bash
# Debian/Ubuntu
sudo apt-get update
sudo apt-get install mysql-client pigz sshpass pv

# RHEL/CentOS
sudo yum install mysql pigz sshpass pv
```

### Configuration

1. Edit the configuration section in `mysql_backup.sh`:

```bash
# MySQL Settings
DB_PASS="your_database_password"
DATABASES=("webapp" "analytics")

# Path Configuration
BACKUP_ROOT="/var/backups/mysql"
```

## Usage 🚀

Basic execution:
```bash
chmod +x mysql_backup.sh
./mysql_backup.sh
```

Sample output:
```
[2023-08-20 14:30:00] Starting backup for database: webapp
Progress: [2/5] Backing up webapp database
 5GiB 0:03:15 [26.2MiB/s] [===============================>] 100%
[2023-08-20 14:33:15] Backup completed successfully
```

### Cron Job Setup
```bash
# Daily at 1 AM
0 1 * * * /path/to/mysql_backup.sh >> /var/log/mysql_backup.log 2>&1
```

## Security 🔒
1. **Credential Security**
   ```bash
   chmod 600 mysql_backup.sh
   echo "[client]\nuser=root\npassword=your_password" > ~/.my.cnf
   chmod 600 ~/.my.cnf
   ```

2. **SSH Key Authentication**
   ```bash
   ssh-keygen -t ed25519
   ssh-copy-id -i ~/.ssh/id_ed25519.pub backup_user@backup.example.com
   ```

## License 📜
This project is licensed under the **GNU General Public License v3.0**.  
Full license text: [LICENSE](LICENSE)

---
Enterprise MySQL backup solution with GPLv3 license. Features parallel compression, transaction-safe backups, and encrypted SSH transfers. Includes daily/weekly/monthly retention policies. Ideal for production environments on Ubuntu/RHEL/CentOS.
```

**Key Changes from PostgreSQL Version:**
1. Replaced `pg_dump` with `mysqldump`
2. Changed authentication method to MySQL format
3. Added `--single-transaction` for InnoDB safety
4. Updated prerequisite packages
5. Modified security instructions for MySQL credentials
6. Changed configuration variables (`SCHEMAS` → `DATABASES`)
7. Updated example databases and timings
8. Adjusted progress messages for MySQL context
9. Changed default backup directory to `/var/backups/mysql`
10. Updated log file path to `/var/log/mysql_backup.log`

**Usage Notes:**
1. For large databases, consider adding `--max-allowed-packet` to mysqldump
2. Adjust `--single-transaction` based on storage engine usage
3. Test with `--no-data` first to verify connectivity
4. Monitor MySQL user privileges for backup operations
5. Consider using `mydumper` for parallel backups in future versions
