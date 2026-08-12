#!/bin/sh
# Runs once, automatically, right after `occ maintenance:install` on a
# fresh Nextcloud instance (Nextcloud image hook: post-installation).
# memcache.local -> APCu: fast per-request/per-process cache, already
# bundled in this image; no reason to pay a network round-trip to Redis
# for it. memcache.distributed and memcache.locking -> Redis: these two
# specifically need to be shared and atomic across requests/containers,
# which APCu (process-local) cannot do - Redis is what actually makes
# transactional file locking work correctly.
set -e

run() {
    if [ "$(id -u)" = "0" ]; then
        su -p www-data -s /bin/sh -c "$1"
    else
        sh -c "$1"
    fi
}

run "php /var/www/html/occ config:system:set memcache.local --value='\\OC\\Memcache\\APCu'"
run "php /var/www/html/occ config:system:set memcache.distributed --value='\\OC\\Memcache\\Redis'"
run "php /var/www/html/occ config:system:set memcache.locking --value='\\OC\\Memcache\\Redis'"
run "php /var/www/html/occ config:system:set redis host --value='redis'"
run "php /var/www/html/occ config:system:set redis port --value=6379 --type=integer"
run "php /var/www/html/occ config:system:set redis password --value='${REDIS_PASSWORD}'"
