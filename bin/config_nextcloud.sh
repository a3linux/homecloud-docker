#!/usr/bin/env bash
NC_CONTAINER_NAME="homecloud_nextcloudapp"
usage() {
    echo "Usage: $0 -a APP"
    echo "  APP can be, "
    echo "    nextcloud      -  system and global level configurations set,"
    echo "       please set environment NC_DOMAIN and NC_PORT with nextcloud DNS name and server port to filful the settings, e.g. export NC_DOMAIN=nc.sample.com NC_PORT=443(default one), for local or development environment, the NC_PORT might not be 443, please set it if so."
    echo "    clamav         -  clamav configuration set"
    echo "    code           -  Nextcloud(Collabora) office related set, please set the environment WOPI_URL(code server URL) and CODE_SERVER_IP(server IP) to finish the Nextcloud Office settings"
    echo "    fulltextsearch -  fulltextsearch configuration set"
}

error_exit() {
    usage
    exit 1
}

TARGET_APP=""
while getopts "a:h" arg
do
    case ${arg} in
        a)
            TARGET_APP=${OPTARG}
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${TARGET_APP}" ]; then
    error_exit
fi

# Check container is running
running_container=$(docker ps -a -f name=homecloud_nextcloudapp --format '{{.Name}}' 2>/dev/null | grep homecloud_nextcloudapp | head -n1)

if [ "${running_container}" == "${NC_CONTAINER_NAME}" ]; then
    echo "Nextcloud app container is running"
else
    echo "Nextcloud app container is not running, please check!"
    error_exit
fi

case "${TARGET_APP}" in
    nextcloud)
        # Basic settings
        if [ -z "${NC_DOMAIN}" ]; then
            echo "No NC_DOMAIN set!"
            error_exit
        fi
        if [ -z "${NC_PORT}" ]; then
            NC_PORT=443
        fi
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set loglevel --value=2
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set log_type --value=file
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set logfile --value="/var/www/html/data/nextcloud.log"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set log_rotate_size --value="10485760"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ app:enable admin_audit
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:app:set admin_audit logfile --value="/var/www/html/data/audit.log"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set log.condition apps 0 --value="admin_audit"

        # Reverse proxy related settings
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set trusted_domains 0 --value="${NC_DOMAIN}"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set overwrite.cli.url --value "https://${NC_DOMAIN}:${NC_PORT}"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set overwritehost --value "${NC_DOMAIN}:${NC_PORT}"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set overwriteprotocol --value "https"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set allow_local_remote_servers --value true --type bool

        # trusted_proxies
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set trusted_proxies 0 --value "172.16.0.0/12"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set trusted_proxies 1 --value "10.0.0.0/8"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set trusted_proxies 2 --value "192.168.0.0/16"
        # Set preview providers
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set preview_max_x --value="2048"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set preview_max_y --value="2048"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set jpeg_quality --value="60"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:app:set preview jpeg_quality --value="60"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:delete enabledPreviewProviders
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\Imaginary"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set enabledPreviewProviders 1 --value="OC\\Preview\\Image"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set enabledPreviewProviders 2 --value="OC\\Preview\\MarkDown"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set enabledPreviewProviders 3 --value="OC\\Preview\\MP3"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set enabledPreviewProviders 4 --value="OC\\Preview\\TXT"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set enabledPreviewProviders 5 --value="OC\\Preview\\OpenDocument"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set enabledPreviewProviders 6 --value="OC\\Preview\\PDF"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set enabledPreviewProviders 7 --value="OC\\Preview\\HEIC"
        #docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set enabledPreviewProviders 8 --value="OC\\Preview\\Movie"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set preview_imaginary_url --value="http://imaginary:9000"
        docker exec -i -u www-data "${NEXTCLOUD_CONTAINER_NAME}" php /var/www/html/occ config:system:set enable_previews --value=true --type=boolean

        ;;
    clamav)
        # Set ClamAV
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:install files_antivirus
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:update files_antivirus
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:enable files_antivirus
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ config:app:set files_antivirus av_mode --value="daemon"
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ config:app:set files_antivirus av_port --value="3310"
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ config:app:set files_antivirus av_host --value="calmav"
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ config:app:set files_antivirus av_stream_max_length --value="104857600"
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ config:app:set files_antivirus av_max_file_size --value="-1"
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ config:app:set files_antivirus av_infected_action --value="only_log"
        ;;
    code)
        if [ -z "${WOPI_URL}" ] || [ -z "${CODE_SERVER_IP}" ]; then
            echo "Please setup the environment variable WOPI_URL or CODE_SERVER_IP to finish the Collabora config!"
            error_exit
        fi
        # set Nextcloud Office(Collabora)
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:install richdocuments
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:update richdocuments
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:enable richdocuments
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ config:app:set richdocuments wopi_url --value="${WOPI_URL}"
        # Set ALLOW IP LIST of Collabora, server public IP address plus private ips, 192.168.*.*, 172.12.*.* and 10.*.*.* should be added.
        PRIVATE_IPS="127.0.0.1/8,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,fd00::/8,::1"
        COLLABORA_ALLOW_LIST="${PRIVATE_IPS},${CODE_SERVER_IP}"
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ config:app:set richdocuments wopi_allowlist --value="$COLLABORA_ALLOW_LIST"
        ;;
    fulltextsearch)
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:install fulltextsearch
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:enable fulltextsearch
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:update fulltextsearch
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:install fulltextsearch_elasticsearch
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:enable fulltextsearch_elasticsearch
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:update fulltextsearch_elasticsearch
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:install files_fulltextsearch
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:enable files_fulltextsearch
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ app:update files_fulltextsearch
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ fulltextsearch:configure '{"search_platform":"OCA\\FullTextSearch_Elasticsearch\\Platform\\ElasticSearchPlatform"}'
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ fulltextsearch_elasticsearch:configure "{\"elastic_host\":\"http://elasticsearch:9200\",\"elastic_index\":\"homecloud-nextcloud\"}"
        docker exec -i -u www-data "${NC_CONTAINER_NAME}" php /var/www/html/occ files_fulltextsearch:configure "{\"files_pdf\":\"1\",\"files_office\":\"1\"}"
        ;;
    *)
        echo "Unknown or unsupport app!"
        error_exit
        ;;
esac
