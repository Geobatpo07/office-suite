#!/bin/sh
# Runs once, automatically, right after `occ maintenance:install` on a
# fresh Nextcloud instance (Nextcloud image hook: post-installation).
# Installs Nextcloud Talk and points it at the coturn service for
# STUN/TURN. WebRTC media is negotiated directly between the browser
# and coturn over UDP - Traefik can't proxy that (no HTTP host to route
# on), so coturn's ports are published straight to the host and Talk is
# told to use "localhost", not a *.localhost/.test domain: this only
# works when the browser is on the same machine as Docker Desktop,
# which matches every other assumption this stack already makes
# (mkcert -install, hosts file entries, etc.).
set -e

run() {
    if [ "$(id -u)" = "0" ]; then
        su -p www-data -s /bin/sh -c "$1"
    else
        sh -c "$1"
    fi
}

run "php /var/www/html/occ app:install spreed || php /var/www/html/occ app:enable spreed"
run "php /var/www/html/occ talk:stun:add 'localhost:3478'"
run "php /var/www/html/occ talk:turn:add turn localhost udp --secret='${TURN_SECRET}'"
