#!/usr/bin/env bash
NC_CONTAINER_NAME="homecloud_nextcloudapp"
# Source path
mypath=$(realpath "${BASH_SOURCE:-$0}")
MYSELF_PATH=$(dirname "${mypath}")
NEXTCLOUD_APPS=$(cat "${MYSELF_PATH%%\/bin}"/etc/nextcloud.apps)

for app in ${NEXTCLOUD_APPS}
do
    docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:install "${app}"
    docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:update "${app}"
done
