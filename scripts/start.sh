#!/bin/sh
# One-command startup: creates .env / TLS certs if this is a first run,
# brings the whole stack up, waits for Nextcloud and Keycloak to finish
# their first-boot install hooks, then prints every service's URL.
# Safe to re-run any time - `docker compose up -d` never touches existing
# data, this script does not wipe or reset anything.
set -eu

# See the matching note in scripts/backup.sh: avoids Git Bash mangling
# Unix-looking paths inside arguments passed to docker.
export MSYS_NO_PATHCONV=1

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
    echo "==> No .env found - creating one from .env.example"
    cp .env.example .env
    echo "    Every secret is still a 'changeme' placeholder (except two that"
    echo "    must match keycloak/realm-office.json - see README). Fine to"
    echo "    poke around, but replace them with 'openssl rand -hex 24' before"
    echo "    keeping this instance around for real."
fi

if [ ! -f traefik/certs/ca.crt ]; then
    echo "==> No local CA found - generating TLS certificates (traefik/gen-certs.sh)"
    mkdir -p traefik/certs
    docker run --rm \
        -v "$(pwd)/traefik/certs:/certs" \
        -v "$(pwd)/traefik/gen-certs.sh:/gen-certs.sh:ro" \
        --entrypoint sh alpine/openssl /gen-certs.sh
    echo "    To avoid browser warnings, import traefik/certs/ca.crt into your"
    echo "    OS/browser's trusted root certificate store."
fi

HOSTS_FILE="/c/Windows/System32/drivers/etc/hosts"
if [ -f "$HOSTS_FILE" ] && ! grep -q "auth.test" "$HOSTS_FILE" 2>/dev/null; then
    echo "==> WARNING: auth.test is missing from $HOSTS_FILE"
    echo "    Keycloak needs it explicitly - unlike the other *.localhost domains,"
    echo "    browsers don't auto-resolve it (see README, step 4). Run as"
    echo "    Administrator:"
    echo "      echo 127.0.0.1 auth.test >> $HOSTS_FILE"
fi

echo "==> Starting the stack"
docker compose --env-file .env up -d

echo "==> Waiting for Nextcloud and Keycloak to finish first-boot setup (can take ~1-2 min on a fresh volume)..."
ready=0
for i in $(seq 1 60); do
    nc_ok=0
    kc_ok=0
    # `curl -o /dev/null` (not shell-redirected) fails with a write error
    # under MSYS_NO_PATHCONV=1 - it stops Git Bash from translating
    # /dev/null into something curl.exe can actually write to on Windows,
    # even though the HTTP request itself succeeds. Shell redirection
    # isn't a curl argument, so it's unaffected.
    curl -sk --max-time 3 "https://nextcloud.localhost:8443/status.php" >/dev/null && nc_ok=1 || true
    curl -sk --max-time 3 --resolve auth.test:8443:127.0.0.1 "https://auth.test:8443/realms/office" >/dev/null && kc_ok=1 || true
    if [ "$nc_ok" = "1" ] && [ "$kc_ok" = "1" ]; then
        ready=1
        break
    fi
    sleep 2
done
[ "$ready" = "1" ] || echo "    Still starting up after 2 minutes - check 'docker compose logs -f nextcloud keycloak' if a URL below doesn't load yet."

cat <<'EOF'

==> Office Suite is up:

  Nextcloud    https://nextcloud.localhost:8443
  OnlyOffice   https://office.localhost:8443    (open a document from Nextcloud's Files app)
  HedgeDoc     https://notes.localhost:8443
  Keycloak     https://auth.test:8443/admin/
  Mailpit      https://mail.localhost:8443
  MinIO        https://storage.localhost:8443
  Traefik      http://localhost:8089/dashboard/

  Calendar, Contacts and Talk are Nextcloud apps - no separate URL.
  Credentials are in .env. Demo Keycloak login: demo / demo.
EOF
