#!/usr/bin/env bash
# Generate/Maintenance a HomeCloud deployment environment
#
declare -A colors
colors[Color_Off]='\033[0m'
colors[Red]='\033[0;31m'
colors[Green]='\033[0;32m'
colors[Yellow]='\033[0;33m'
colors[Blue]='\033[0;34m'
colors[Purple]='\033[0;35m'
colors[Cyan]='\033[0;36m'
colors[White]='\033[0;37m'

# HomeCloud deployment environment configuration file
set -a
SETUP_ENV_FULLPATH=""

usage() {
    echo -e "Usage: ${colors[Cyan]}$0 -c some_path/homecloud.<env>${colors[Color_Off]}"
    echo -e "  Please provide the homecloud service environment file, e.g. ${colors[Cyan]}<some_path>/homecloud.dev${colors[Color_Off]}"
    echo -e "  Copy the ${colors[Red]}homecloud.env${colors[Color_Off]} to start, the filename should be ${colors[Purple]}homecloud.<env>${colors[Color_Off]}, <env> should be ${colors[Purple]}dev | prod${colors[Color_Off]}"
}

error_exit() {
    usage
    exit 1
}

create_subfolders() {
    local base_dir=$1
    local -n arr=$2
    for sub_folder in ${arr[@]}
    do
        mkdir -p ${base_dir}/${sub_folder}
    done
}

# Process options
while getopts "c:h" arg
do
    case ${arg} in
        c)
            SETUP_ENV_FULLPATH=${OPTARG}
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${SETUP_ENV_FULLPATH}" ] || [ ! -f "${SETUP_ENV_FULLPATH}" ]; then
    error_exit
fi

SETUP_ENV_FILENAME=$(basename "${SETUP_ENV_FULLPATH}")
TARGET_ENV=${SETUP_ENV_FILENAME##*.}
filename=${SETUP_ENV_FILENAME%.*}

if [ "${filename}" != "homecloud" ]; then
    error_exit
fi

echo -e "${colors[Green]}Source the deployment environment configuration: ${colors[Blue]}${SETUP_ENV_FULLPATH} ${colors[Color_Off]}"
source "${SETUP_ENV_FULLPATH}"

echo -e "${colors[Green]}Start prepare the HomeCloud deployment environment: ${colors[Blue]}${TARGET_ENV} ${colors[Color_Off]}"
if [ ! -d "${SERVICE_DESTINATION}" ]; then
    echo -e "!!!Folder ${colors[Red]}${SERVICE_DESTINATION} ${colors[Color_Off]}does not exist or can not access!!!"
    error_exit
fi

# myself path
mypath=$(realpath "${BASH_SOURCE:-$0}")
MYSELF_PATH=$(dirname "${mypath}")
HOMECLOUD_REPOS_PATH="${MYSELF_PATH}"
TEMPLATER="${HOMECLOUD_REPOS_PATH}/templater.sh"
DOCKER_COMPOSE_ENV_YML="${SERVICE_DESTINATION}/docker-compose.${TARGET_ENV}.yml"

SERVICE_DESTINATION_BIN="${SERVICE_DESTINATION}/bin"
START_SH="${SERVICE_DESTINATION_BIN}/start.sh"
START_DAEMON_SH="${SERVICE_DESTINATION_BIN}/start.daemon.sh"
STOP_SH="${SERVICE_DESTINATION_BIN}/stop.sh"
PULL_SH="${SERVICE_DESTINATION_BIN}/pull.sh"
RESTART_SH="${SERVICE_DESTINATION_BIN}/restart.sh"
START_DBONLY_SH="${SERVICE_DESTINATION_BIN}/start.dbonly.sh"
STOP_DBONLY_SH="${SERVICE_DESTINATION_BIN}/stop.dbonly.sh"

# Homecloud service
echo -e "${colors[Green]}  HomeCloud service setup in ${colors[Blue]}${SERVICE_DESTINATION} ${colors[Color_Off]}"
echo -e "${colors[Green]}    - HomeCloud service bin ${colors[Blue]}${SERVICE_DESTINATION_BIN} ${colors[Color_Off]}"
mkdir -p "${SERVICE_DESTINATION}/bin"
rsync -ar "${HOMECLOUD_REPOS_PATH}/bin/" "${SERVICE_DESTINATION}/bin/"
echo "${SERVICE_DESTINATION_BIN}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a start" > "${START_SH}"
echo "${SERVICE_DESTINATION_BIN}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a restart" > "${RESTART_SH}"
echo "${SERVICE_DESTINATION_BIN}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a stop" > "${STOP_SH}"
echo "${SERVICE_DESTINATION_BIN}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a start -d" > "${START_DAEMON_SH}"
echo "${SERVICE_DESTINATION_BIN}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a start -b" > "${START_DBONLY_SH}"
echo "${SERVICE_DESTINATION_BIN}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a stop -b" > "${STOP_DBONLY_SH}"
echo "${SERVICE_DESTINATION_BIN}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a pull" > "${PULL_SH}"
chmod +x "${START_SH}" "${STOP_SH}" "${START_DAEMON_SH}" "${START_DBONLY_SH}" "${STOP_DBONLY_SH}" "${RESTART_SH}" "${PULL_SH}"

CREATE_DATABASES="${SERVICE_DESTINATION_BIN}/create_databases.sh"
CREATE_POSTGRES="${SERVICE_DESTINATION_BIN}/create_postgresdb.sh"
CREATE_MARIADB="${SERVICE_DESTINATION_BIN}/create_mariadb.sh"
echo "#!/usr/bin/env bash" > "${CREATE_DATABASES}"
# PostgreSQL
if [ -x "${CREATE_POSTGRES}" ]; then
    echo -e "${colors[Green]}    - Generate PostgreSQL creat script.${colors[Color_Off]}"
    echo "${CREATE_POSTGRES} -n authentik -u authentik -s ${VAULT_BASE} -d homecloud_postgres"  >> "${CREATE_DATABASES}"
    echo "${CREATE_POSTGRES} -n nextcloud -u nextcloud -s ${VAULT_BASE} -d homecloud_postgres" >> "${CREATE_DATABASES}"
fi
# MariaDB(not used yet)
if [ -x "${CREATE_MARIADB}" ]; then
    echo -e "${colors[Green]}    - No MariaDB!${colors[Color_Off]}"
fi
chmod +x "${CREATE_DATABASES}"

echo -e "${colors[Green]}    - HomeCloud service etc ${colors[Blue]}${SERVICE_DESTINATION}/etc ${colors[Color_Off]}"
mkdir -p "${SERVICE_DESTINATION}/etc"
rsync -ar "${HOMECLOUD_REPOS_PATH}/etc/" "${SERVICE_DESTINATION}/etc/"

HOMECLOUD_ETC_CONFIGS=("etc/cron.daily/homecloud_backup" "etc/cron.hourly/homecloud_backup" "etc/systemd/system/multi-user.target.wants/docker-cleanup.service" "etc/systemd/system/multi-user.target.wants/docker-cleanup.timer" "etc/systemd/system/multi-user.target.wants/homecloud.service")
for cf in ${HOMECLOUD_ETC_CONFIGS[@]}
do
    ${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/${cf}" > "${SERVICE_DESTINATION}/${cf}"
done

echo -e "${colors[Green]}    - HomeCloud service ${colors[Blue]}${SERVICE_DESTINATION}/docker-compose.yml ${colors[Color_Off]}"
rsync -a "${HOMECLOUD_REPOS_PATH}/docker-compose.yml" "${SERVICE_DESTINATION}/docker-compose.yml"

# Generate/Update vault
"${SERVICE_DESTINATION_BIN}"/vault.setup.sh -a "${VAULT_BASE}"

# Core Services
CORESERVICES_APP_FOLDERS=("lb" "lb/conf.d" "lb/certs" "lb/webroot" "mariadb" "postgres" "redis" "authentik/media" "authentik/templates" "authentik/certs" "authentik/extra" "authentik/data" "authentik/dist" "nextcloud" "nextcloud-app" "nextcloud-web" "elasticsearch")
CORESERVICES_DATA_FOLDERS=("mariadb" "postgres" "nextcloud")
LB_NGINX_CONF="${APPS_BASE}/lb/nginx.conf"
LB_NGINX_CONF_D="${APPS_BASE}/lb/conf.d"
LB_NGINX_WEBROOT="${APPS_BASE}/lb/webroot"
if [ -z "${CERTIFICATE_PATH}" ]; then
    LB_NGINX_CERTS="${APPS_BASE}/lb/certs"
else
    LB_NGINX_CERTS="${CERTIFICATE_PATH}"
fi
PRIMARY_CERT_PATH="/certs/${PRIMARY_CERT_FILE:=fullchain.pem}"
PRIMARY_PRIVATE_KEY_PATH="/certs/${PRIMARY_PRIVATE_KEY_FILE:=private.pem}"
AUTHENTIK_CERT_PATH="/certs/${AUTHENTIK_CERT_FILE:=fullchain.pem}"
AUTHENTIK_PRIVATE_KEY_PATH="/certs/${AUTHENTIK_PRIVATE_KEY_FILE:=private.pem}"
MARIADB_DATA_PATH="${APPS_BASE}/mariadb"
POSTGRES_DATA_PATH="${APPS_BASE}/postgres"
REDIS_DATA_PATH="${APPS_BASE}/redis"
AUTHENTIK_MEDIA="${APPS_BASE}/authentik/media"
AUTHENTIK_TEMPLATES="${APPS_BASE}/authentik/templates"
AUTHENTIK_USER_SETTINGS_PY="${APPS_BASE}/authentik/data/user_settings.py"
AUTHENTIK_CERTS="${APPS_BASE}/authentik/certs"
AUTHENTIK_ENV_FILE="authentik.${TARGET_ENV}"
NEXTCLOUD_WEBROOT="${APPS_BASE}/nextcloud"
NEXTCLOUD_DATA="${DATA_BASE}/nextcloud"
NEXTCLOUD_WWW_CONF="${APPS_BASE}/nextcloud-app/www.conf"
NEXTCLOUD_NGINX_CONF="${APPS_BASE}/nextcloud-web/nginx.conf"
ELASTICSEARCH_DATA="${APPS_BASE}/elasticsearch"
echo -e "${colors[Green]}  Core services setup${colors[Color_Off]}"
mkdir -p "${VAULT_BASE}"
mkdir -p "${APPS_BASE}"
mkdir -p "${DATA_BASE}"
create_subfolders ${APPS_BASE} CORESERVICES_APP_FOLDERS
create_subfolders ${DATA_BASE} CORESERVICES_DATA_FOLDERS
if [ -f "${SERVICE_DESTINATION}/${AUTHENTIK_ENV_FILE}" ]; then
    echo -e "    ${colors[Cyan]}authentik.${TARGET_ENV} ${colors[Yellow]}existed, skip copy and if you want to update it please do it manually!${colors[Color_Off]}"
else
    echo -e "    ${colors[Cyan]}Copy env file authentik.${TARGET_ENV}${colors[Color_Off]}"
    cp "${HOMECLOUD_REPOS_PATH}/env_files/authentik.env" "${SERVICE_DESTINATION}/${AUTHENTIK_ENV_FILE}"
fi
${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/docker/core-services.yml" > ${DOCKER_COMPOSE_ENV_YML}

CORE_SERVICES_CONF_FILES=("lb/nginx.conf" "lb/conf.d/00-default.conf" "lb/conf.d/01-authentik.conf" "authentik/data/user_settings.py" "authentik/dist/custom.css" "lb/webroot/404.html" "lb/webroot/50x.html" "lb/webroot/index.html" "nextcloud-app/www.conf" "nextcloud-web/nginx.conf")
for cf in ${CORE_SERVICES_CONF_FILES[@]}
do
    ${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/conf/${cf}" > "${APPS_BASE}/${cf}"
done
# Sync local certificates
rsync -ar "${HOMECLOUD_REPOS_PATH}/conf/lb/certs/" "${APPS_BASE}/lb/certs/"

SERVICES_PLACEHOLDER="##"
# Code
CODE_APP_FOLDERS=("code/fonts")
CODE_ENV_FILE="code.${TARGET_ENV}"
CODE_FONTS_PATH="${APPS_BASE}/code/fonts"
CODE_CERT_PATH="/certs/${CODE_CERT_FILE:=fullchain.pem}"
CODE_PRIVATE_KEY_PATH="/certs/${CODE_PRIVATE_KEY_FILE:=private.pem}"
if [ "${CODE_SERVER_ENABLED}" == "yes" ]; then
    echo -e "${colors[Green]}  Code setup${colors[Color_Off]}"
    create_subfolders ${APPS_BASE} CODE_APP_FOLDERS
    ${TEMPLATE} "${HOMECLOUD_REPOS_PATH}/conf/lb/conf.d/02-code.conf" > "${APPS_BASE}/lb/conf.d/02-code.conf"
    if [ -f "${SERVICE_DESTINATION}/${CODE_ENV_FILE}" ]; then
        echo -e "   ${colors[Cyan]}code.${TARGET_ENV} existed, skip copy and if you want to update it please do it manually!${colors[Color_Off]}"
    else
        echo -e "   ${colors[Cyan]}Copy env file code.${TARGET_ENV}${colors[Color_Off]}"
        ${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/env_files/code.env" > "${SERVICE_DESTINATION}/${CODE_ENV_FILE}"
    fi
    echo -e "   ${colors[Cyan]}Generating code volumes${colors[Color_Off]}"
    ${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/docker/code.yml" >> ${DOCKER_COMPOSE_ENV_YML}
else
    if [ -f "${APPS_BASE}/lb/conf.d/02-code.conf" ]; then
        rm -f "${APPS_BASE}/lb/conf.d/02-code.conf"
    fi
fi

# ClamAV
CLAMAV_APP_FOLDERS=("clamav")
CLAMAV_DATA_PATH="${APPS_BASE}/clamav"
if [ "${CLAMAV_SERVER_ENABLED}" == "yes" ]; then
    echo -e "${colors[Green]}  ClamAV setup${colors[Color_Off]}"
    create_subfolders ${APPS_BASE} CLAMAV_APP_FOLDERS
    echo -e "    ${colors[Cyan]}Generating ClamAV volumes${colors[Color_Off]}"
    ${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/docker/clamav.yml" >> ${DOCKER_COMPOSE_ENV_YML}
fi

# CalibreWeb
CALIBREWEB_APP_FOLDERS=("calibreweb")
CALIBREWEB_DATA_FOLDERS=("calibre")
CALIBREWEB_ENV_FILE="calibreweb.${TARGET_ENV}"
CALIBREWEB_CONFIG_PATH="${APPS_BASE}/calibreweb"
CALIBREWEB_DATA_PATH="${DATA_BASE}/calibre"
CALIBREWEB_CERT_PATH="/certs/${CALIBREWEB_CERT_FILE:=fullchain.pem}"
CALIBREWEB_PRIVATE_KEY_PATH="/certs/${CALIBREWEB_PRIVATE_KEY_FILE:=private.pem}"
if [ "${CALIBREWEB_ENABLED}" == "yes" ]; then
    echo -e "${colors[Green]}  Calibre-Web setup${colors[Color_Off]}"
    create_subfolders ${APPS_BASE} CALIBREWEB_APP_FOLDERS
    create_subfolders ${DATA_BASE} CALIBREWEB_DATA_FOLDERS
    ${TEMPLATE} "${HOMECLOUD_REPOS_PATH}/conf/lb/conf.d/03-calibreweb.conf" > "${APPS_BASE}/lb/conf.d/03-calibreweb.conf"
    if [ -f "${SERVICE_DESTINATION}/${CALIBREWEB_ENV_FILE}" ]; then
        echo -e "    ${colors[Red]}${CALIBREWEB_ENV_FILE} ${colors[Yellow]}exists and will not update it to avoid configuration overwrite${colors[Color_Off]}"
        echo -e "${colors[Yellow]}   !!! Please check and update ${CALIBREWEB_ENV_FILE}!${colors[Color_Off]}"
    else
        echo -e "   ${colors[Cyan]}Generating calibre-web ${CALIBREWEB_ENV_FILE}${colors[Color_Off]}"
        ${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/env_files/calibre.env" > "${SERVICE_DESTINATION}/${CALIBREWEB_ENV_FILE}"
    fi
    echo -e "   ${colors[Cyan]}Generating calibre-web volumes${colors[Color_Off]}"
    ${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/docker/calibreweb.yml" >> "${DOCKER_COMPOSE_ENV_YML}"
else
    if [ -f "${APPS_BASE}/lb/conf.d/03-calibreweb.conf" ]; then
        rm -f "${APPS_BASE}/lb/conf.d/03-calibreweb.conf"
    fi
fi

# jellyfin
JELLYFIN_APP_FOLDERS=("jellyfin")
JELLYFIN_DATA_FOLDERS=("jellyfin")
JELLYFIN_ENV_FILE="jellyfin.${TARGET_ENV}"
JELLYFIN_CERT_PATH=/certs/${JELLYFIN_CERT_FILE:=fullchain.pem}
JELLYFIN_PRIVATE_KEY_PATH=/certs/${JELLYFIN_PRIVATE_KEY_FILE:=private.pem}
JELLYFIN_CONFIG_PATH="${APPS_BASE}/jellyfin"
JELLYFIN_DATA_PATH="${DATA_BASE}/jellyfin"
if [ "${JELLYFIN_ENABLED}" == "yes" ]; then
    echo -e "${colors[Green]}  Jellyfin setup${colors[Color_Off]}"
    create_subfolders ${APPS_BASE} JELLYFIN_APP_FOLDERS
    create_subfolders ${DATA_BASE} JELLYFIN_DATA_FOLDERS
    ${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/conf/lb/conf.d/04-jellyfin.conf" > "${APPS_BASE}/lb/conf.d/04-jellyfin.conf"
    if [ -f "${SERVICE_DESTINATION}/${JELLYFIN_ENV_FILE}" ]; then
        echo -e "    ${colors[Cyan]}${JELLYFIN_ENV_FILE} ${colors[Yellow]}exists and will not update it to avoid configuration overwrite${colors[Color_Off]}"
        echo -e "${colors[Yellow]}    !!! Please check and update ${CALIBREWEB_ENV_FILE} !${colors[Color_Off]}"
    else
        echo -e "   ${colors[Cyan]}Generating jellyfin ${JELLYFIN_ENV_FILE}${colors[Color_Off]}"
        ${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/env_files/jellyfin.env" > "${SERVICE_DESTINATION}/${JELLYFIN_ENV_FILE}"
    fi
    ${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/docker/jellyfin.yml" >> "${DOCKER_COMPOSE_ENV_YML}"
else
    if [ -f "${APPS_BASE}/lb/conf.d/04-jellyfin.conf" ]; then
        rm -f "${APPS_BASE}/lb/conf.d/04-jellyfin.conf"
    fi
fi

# Talk
TALK_TURN_SECRET=$(cat "${VAULT_BASE}/talk_turn_secret.txt")
TALK_SIGNALING_SECRET=$(cat "${VAULT_BASE}/talk_signaling_secret.txt")
if [ "${TALK_SERVER_ENABLED}" == "yes" ]; then
    echo -e "${colors[Green]}  Talk setup${colors[Color_Off]}"
    ${TEMPLATER} "${HOMECLOUD_REPOS_PATH}/docker/talk.yml" >> "${DOCKER_COMPOSE_ENV_YML}"
fi

# Verify and generate new secrets
echo -e "${colors[Cyan]}Generate docker-compose secrets section${colors[Color_Off]}"
echo "" >> "${DOCKER_COMPOSE_ENV_YML}"
"${SERVICE_DESTINATION_BIN}"/vault.setup.sh -o -a "${VAULT_BASE}" >> "${DOCKER_COMPOSE_ENV_YML}"

echo -e "${colors[Green]}Complete prepare HomeCloud deployment environment ${colors[Blue]}${TARGET_ENV}${colors[Color_Off]}"
