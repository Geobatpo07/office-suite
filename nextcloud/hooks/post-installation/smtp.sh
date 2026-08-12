#!/bin/sh
# Runs once, automatically, right after `occ maintenance:install` on a
# fresh Nextcloud instance (Nextcloud image hook: post-installation).
# Points outgoing mail (share notifications, password resets, activity
# digests) at Mailpit, a local SMTP catch-all - nothing gets delivered
# anywhere real, it's just viewable at https://mail.localhost:8443.
set -e

run() {
    if [ "$(id -u)" = "0" ]; then
        su -p www-data -s /bin/sh -c "$1"
    else
        sh -c "$1"
    fi
}

run "php /var/www/html/occ config:system:set mail_smtpmode --value='smtp'"
run "php /var/www/html/occ config:system:set mail_smtphost --value='mailpit'"
run "php /var/www/html/occ config:system:set mail_smtpport --value='1025'"
run "php /var/www/html/occ config:system:set mail_smtpauth --type=boolean --value=false"
run "php /var/www/html/occ config:system:set mail_smtpsecure --value=''"
run "php /var/www/html/occ config:system:set mail_domain --value='nextcloud.localhost'"
run "php /var/www/html/occ config:system:set mail_from_address --value='nextcloud'"
