#!/bin/sh
# Runs once, automatically, right after `occ maintenance:install` on a
# fresh Nextcloud instance (Nextcloud image hook: post-installation).
# Installs Nextcloud Talk and points it at the coturn service for
# STUN/TURN. WebRTC media is negotiated directly between the browser and
# coturn over UDP - Traefik can't proxy that (no HTTP host to route on),
# so coturn's ports are published straight to the host and Talk is told
# to reach it at $TURN_HOST, a real routable address for whoever's
# browser is making the call - not a *.localhost/.test domain, those
# only resolve to the machine running Docker Desktop, never to a peer
# on the network.
#
# Defaults to "localhost" (single-machine use, the original behaviour).
# Set TURN_HOST in .env to this machine's LAN IP (`ipconfig` / `ip a`) to
# let other devices on the same network make/receive Talk calls too -
# see the README for what else that does and doesn't require.
set -e

TURN_HOST="${TURN_HOST:-localhost}"

run() {
    if [ "$(id -u)" = "0" ]; then
        su -p www-data -s /bin/sh -c "$1"
    else
        sh -c "$1"
    fi
}

run "php /var/www/html/occ app:install spreed || php /var/www/html/occ app:enable spreed"
run "php /var/www/html/occ talk:stun:add '${TURN_HOST}:3478'"
run "php /var/www/html/occ talk:turn:add turn ${TURN_HOST} udp --secret='${TURN_SECRET}'"
