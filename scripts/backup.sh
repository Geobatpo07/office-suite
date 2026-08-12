#!/bin/sh
# Full backup of the office suite: a logical (pg_dump) dump of both
# Postgres databases, plus a tar of every volume that holds user data
# (Nextcloud app/config, MinIO - Nextcloud's actual primary file storage
# since files no longer live under nextcloud_data, HedgeDoc uploads,
# OnlyOffice's own storage, Keycloak's realm/user database). Everything
# lands in backups/<UTC timestamp>/. redis_data is deliberately skipped:
# it's pure cache/lock state, safe to lose, and gets rebuilt on its own.
#
# pg_dump instead of a raw tar of the Postgres data directories: a plain
# SQL dump is consistent (no risk of copying half-written pages from a
# live database) and portable across Postgres versions/architectures; a
# volume tar of $PGDATA is not.
#
# --no-owner --no-acl: table/sequence ownership in a dump is only ever
# meant to be restored into a database whose role names exactly match the
# source - not guaranteed here (an existing volume's tables can be owned
# by a role that predates the current POSTGRES_USER in .env, e.g. after
# rotating credentials without also reassigning ownership). Dropping
# ownership/ACL statements makes every restore land on whatever role
# performs it, unconditionally.
#
# Nextcloud is put into maintenance mode for the file tar step only, so
# no upload lands half-copied in the archive - the DB dumps run outside
# that window since they don't need it (a single pg_dump statement is
# already transactionally consistent on its own).
set -eu

# On Windows, Git Bash rewrites Unix-looking absolute paths (/bin/sh,
# /var/www/html/...) in command-line arguments before they ever reach
# docker - which corrupts the arguments we pass into `docker compose
# exec`. Harmless everywhere else.
export MSYS_NO_PATHCONV=1

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
    echo "Missing .env - run this from the office-suite repo root after 'cp .env.example .env'." >&2
    exit 1
fi

# Only need COMPOSE_PROJECT_NAME out of .env, to rebuild the real volume
# names (docker compose prefixes every volume with it: <project>_<name>).
COMPOSE_PROJECT_NAME=$(grep -E '^COMPOSE_PROJECT_NAME=' .env | cut -d= -f2-)
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-office_suite}

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT="backups/${STAMP}"
mkdir -p "$OUT"

echo "==> Backing up into $OUT"

echo "==> Dumping nextcloud-db"
docker compose --env-file .env exec -T nextcloud-db \
    sh -c 'pg_dump --no-owner --no-acl -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$OUT/nextcloud-db.sql"

echo "==> Dumping hedgedoc-db"
docker compose --env-file .env exec -T hedgedoc-db \
    sh -c 'pg_dump --no-owner --no-acl -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$OUT/hedgedoc-db.sql"

MAINTENANCE_ON=0
cleanup() {
    if [ "$MAINTENANCE_ON" = "1" ]; then
        echo "==> Disabling Nextcloud maintenance mode"
        docker compose --env-file .env exec -T nextcloud \
            su -p www-data -s /bin/sh -c 'php /var/www/html/occ maintenance:mode --off' || true
    fi
}
trap cleanup EXIT

echo "==> Enabling Nextcloud maintenance mode"
docker compose --env-file .env exec -T nextcloud \
    su -p www-data -s /bin/sh -c 'php /var/www/html/occ maintenance:mode --on'
MAINTENANCE_ON=1

for vol in nextcloud_data minio_data hedgedoc_uploads onlyoffice_data onlyoffice_db keycloak_data; do
    full="${COMPOSE_PROJECT_NAME}_${vol}"
    echo "==> Archiving volume $full"
    docker run --rm \
        -v "${full}:/source:ro" \
        -v "$(pwd)/${OUT}:/backup" \
        alpine tar czf "/backup/${vol}.tar.gz" -C /source .
done

cleanup
trap - EXIT
MAINTENANCE_ON=0

{
    echo "office-suite backup"
    echo "created (UTC): $STAMP"
    echo "compose project: $COMPOSE_PROJECT_NAME"
    echo
    echo "Contents:"
    ls -la "$OUT"
    echo
    echo "NOTE: this backup does NOT include .env. Without the matching"
    echo ".env (DB users/passwords, JWT_SECRET, TURN_SECRET, etc.) a"
    echo "restore cannot reconnect app containers to the restored"
    echo "databases. Keep .env backed up separately (password manager /"
    echo "vault), never alongside this archive."
} > "$OUT/manifest.txt"

echo "==> Backup complete: $OUT"
