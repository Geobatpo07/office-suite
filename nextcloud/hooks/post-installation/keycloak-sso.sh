#!/bin/sh
# Runs once, automatically, right after `occ maintenance:install` on a
# fresh Nextcloud instance (Nextcloud image hook: post-installation).
# Installs the official user_oidc app and registers Keycloak's "office"
# realm as a login provider, so Nextcloud gets the same SSO Keycloak
# already provides for HedgeDoc - no manual occ step on a fresh clone.
#
# Nextcloud reaches Keycloak at https://auth.test:8443 rather than
# auth.localhost like every other public URL in this project: curl
# (used by PHP/Guzzle here) hardcodes any *.localhost host to 127.0.0.1
# per RFC 6761, even with an explicit /etc/hosts entry - that breaks
# user_oidc's server-side discovery/token/userinfo calls. .test doesn't
# have that problem. See docker-compose.yml's keycloak service for detail.
set -e

run() {
    if [ "$(id -u)" = "0" ]; then
        su -p www-data -s /bin/sh -c "$1"
    else
        sh -c "$1"
    fi
}

# Nextcloud's own SSRF guard blocks requests to addresses on the docker
# bridge network (172.16.0.0/12) by default; every service here lives on
# exactly that range.
run "php /var/www/html/occ config:system:set allow_local_remote_servers --type=boolean --value=true"

run "php /var/www/html/occ app:install user_oidc || php /var/www/html/occ app:enable user_oidc"
run "php /var/www/html/occ user_oidc:provider keycloak \
  --clientid='nextcloud-client' \
  --clientsecret='${NEXTCLOUD_OIDC_SECRET}' \
  --discoveryuri='https://auth.test:8443/realms/office/.well-known/openid-configuration' \
  --unique-uid=0 \
  --mapping-uid='preferred_username' \
  --mapping-display-name='name' \
  --mapping-email='email' \
  --scope='openid email profile'"
