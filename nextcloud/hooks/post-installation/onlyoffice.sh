#!/bin/sh
# Runs once, automatically, right after `occ maintenance:install` on a
# fresh Nextcloud instance (Nextcloud image hook: post-installation).
# Installs and wires the official ONLYOFFICE connector app so documents
# open/edit in-browser via the onlyoffice service, without any manual
# occ step on a fresh clone.
set -e

run() {
    if [ "$(id -u)" = "0" ]; then
        su -p www-data -s /bin/sh -c "$1"
    else
        sh -c "$1"
    fi
}

run "php /var/www/html/occ app:install onlyoffice || php /var/www/html/occ app:enable onlyoffice"
run "php /var/www/html/occ config:app:set onlyoffice DocumentServerUrl --value='https://office.localhost:8443/'"
run "php /var/www/html/occ config:app:set onlyoffice DocumentServerInternalUrl --value='http://onlyoffice/'"
run "php /var/www/html/occ config:app:set onlyoffice StorageUrl --value='http://nextcloud/'"
run "php /var/www/html/occ config:app:set onlyoffice jwt_secret --value='${JWT_SECRET}'"
run "php /var/www/html/occ config:app:set onlyoffice jwt_header --value='AuthorizationJwt'"
