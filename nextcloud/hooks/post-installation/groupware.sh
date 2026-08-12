#!/bin/sh
# Runs once, automatically, right after `occ maintenance:install` on a
# fresh Nextcloud instance (Nextcloud image hook: post-installation).
# Calendar (CalDAV) and Contacts (CardDAV) work out of the box once
# installed - no server config needed, unlike OnlyOffice/SSO/SMTP.
set -e

run() {
    if [ "$(id -u)" = "0" ]; then
        su -p www-data -s /bin/sh -c "$1"
    else
        sh -c "$1"
    fi
}

run "php /var/www/html/occ app:install calendar || php /var/www/html/occ app:enable calendar"
run "php /var/www/html/occ app:install contacts || php /var/www/html/occ app:enable contacts"
