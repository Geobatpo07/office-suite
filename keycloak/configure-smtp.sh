#!/bin/sh
# Keycloak's file-based realm import (--import-realm, realm-office.json)
# silently drops the "smtpServer" map for a brand-new realm - the fields
# parse fine (no error in the logs) but never end up on the imported
# realm. Setting the exact same values via the admin REST API works, so
# this one-shot container does that instead, every time it starts
# (idempotent - re-applying the same config is harmless).
set -e

KCADM=/opt/keycloak/bin/kcadm.sh

until $KCADM config credentials --server http://keycloak:8080 --realm master \
  --user "$KEYCLOAK_USER" --password "$KEYCLOAK_PASSWORD" 2>/dev/null; do
  echo "Waiting for Keycloak admin API..."
  sleep 3
done

$KCADM update realms/office \
  -s 'smtpServer.host=mailpit' \
  -s 'smtpServer.port=1025' \
  -s 'smtpServer.from=keycloak@office.localhost' \
  -s 'smtpServer.fromDisplayName=Keycloak' \
  -s 'smtpServer.auth=false' \
  -s 'smtpServer.ssl=false' \
  -s 'smtpServer.starttls=false'

echo "Keycloak SMTP configured."
