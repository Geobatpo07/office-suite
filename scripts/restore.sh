#!/bin/sh
# Disaster recovery: restores a backup produced by scripts/backup.sh.
# DESTRUCTIVE - wipes the current content of every volume being restored
# and drops/recreates both databases. Requires .env to already contain
# the SAME DB user/password/name values that were live when the backup
# was taken (see the note in scripts/backup.sh about backing up .env
# separately - it is never included in the backup archive itself).
set -eu

# See the matching note in scripts/backup.sh: avoids Git Bash mangling
# Unix-looking paths inside arguments passed to `docker compose exec`.
export MSYS_NO_PATHCONV=1

cd "$(dirname "$0")/.."

BACKUP_DIR="${1:-}"
CONFIRM="${2:-}"

if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    echo "Usage: $0 <path-to-backup-dir> [--yes]" >&2
    echo "Available backups:" >&2
    ls -1 backups 2>/dev/null >&2 || true
    exit 1
fi

for f in nextcloud-db.sql hedgedoc-db.sql nextcloud_data.tar.gz hedgedoc_uploads.tar.gz onlyoffice_data.tar.gz onlyoffice_db.tar.gz keycloak_data.tar.gz; do
    if [ ! -f "$BACKUP_DIR/$f" ]; then
        echo "Missing $f in $BACKUP_DIR - not a valid backup produced by scripts/backup.sh." >&2
        exit 1
    fi
done

if [ ! -f .env ]; then
    echo "Missing .env - restore needs the same DB credentials that were live at backup time." >&2
    exit 1
fi

if [ "$CONFIRM" != "--yes" ]; then
    echo "This DESTROYS all current data (Nextcloud files, HedgeDoc notes/uploads,"
    echo "OnlyOffice storage, Keycloak realms/users, both Postgres databases) and"
    echo "replaces it with the contents of: $BACKUP_DIR"
    printf 'Type "yes" to continue: '
    read -r answer
    if [ "$answer" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi
fi

COMPOSE_PROJECT_NAME=$(grep -E '^COMPOSE_PROJECT_NAME=' .env | cut -d= -f2-)
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-office_suite}

echo "==> Stopping the stack (volumes are kept)"
docker compose --env-file .env down

for vol in nextcloud_data hedgedoc_uploads onlyoffice_data onlyoffice_db keycloak_data; do
    full="${COMPOSE_PROJECT_NAME}_${vol}"
    echo "==> Restoring volume $full"
    docker volume create "$full" >/dev/null
    docker run --rm \
        -v "${full}:/target" \
        -v "$(pwd)/${BACKUP_DIR}:/backup:ro" \
        alpine sh -c 'rm -rf /target/* /target/.[!.]* /target/..?* 2>/dev/null; tar xzf "/backup/'"${vol}"'.tar.gz" -C /target'
done

echo "==> Starting databases only"
docker compose --env-file .env up -d nextcloud-db hedgedoc-db
docker compose --env-file .env exec -T nextcloud-db sh -c '
  until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do sleep 1; done
'
docker compose --env-file .env exec -T hedgedoc-db sh -c '
  until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do sleep 1; done
'

echo "==> Restoring nextcloud-db"
docker compose --env-file .env exec -T nextcloud-db sh -c \
    'psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$POSTGRES_DB\"" && psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$POSTGRES_DB\" OWNER \"$POSTGRES_USER\""'
docker compose --env-file .env exec -T nextcloud-db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$BACKUP_DIR/nextcloud-db.sql"

echo "==> Restoring hedgedoc-db"
docker compose --env-file .env exec -T hedgedoc-db sh -c \
    'psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$POSTGRES_DB\"" && psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$POSTGRES_DB\" OWNER \"$POSTGRES_USER\""'
docker compose --env-file .env exec -T hedgedoc-db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$BACKUP_DIR/hedgedoc-db.sql"

echo "==> Starting the full stack"
docker compose --env-file .env up -d

echo "==> Lifting Nextcloud maintenance mode (the backup was taken with it on)"
for i in $(seq 1 30); do
    if docker compose --env-file .env exec -T nextcloud \
        su -p www-data -s /bin/sh -c 'php /var/www/html/occ maintenance:mode --off' 2>/dev/null; then
        break
    fi
    sleep 2
done

echo "==> Restore complete."
