#!/usr/bin/env bash
# Generate HomeCloud service volumes(mount to docker)
#
SETUP_ENV_FULLPATH=""
usage() {
    echo "Usage: $0 -c some_path/homecloud.<env>"
    echo "  Please provide the homecloud service environment file, e.g. some_path/homecloud.dev"
    echo "  You COULD create such file based on templates/homecloud.env.template"
    echo "  The filename should be homecloud.<env>, <env> indicates the deployment, can be dev | prod"
}

error_exit() {
    usage
    exit 1
}

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

source "${SETUP_ENV_FULLPATH}"

if [ ! -d "${SERVICE_DESTINATION}" ]; then
    echo "Folder ${SERVICE_DESTINATION} does not exist or can not access!!!"
    error_exit
fi

APPs="
lb
mariadb
postgres
redis
authentik
nextcloud
nextcloud-web
code
clamav
elasticsearch
"
DATAs="
nextcloud
"
DSTs="
bin
etc
"

for app in ${APPs}
do
    mkdir -p "${APPS_BASE}"/"${app}"
done

for data in ${DATAs}
do
    mkdir -p "${DATA_BASE}"/"${data}"
done

for dst in ${DSTs}
do
    mkdir -p "${SERVICE_DESTINATION}"/"${dst}"
done

mkdir -p "${VAULT_BASE}"
# Source path
mypath=$(realpath "${BASH_SOURCE:-$0}")
MYSELF_PATH=$(dirname "${mypath}")
HC_PROGRAM_PATH="${MYSELF_PATH%%\/bin}"
HC_CONF_SOURCE_PATH="${HC_PROGRAM_PATH}"/conf

echo "Copy scripts and data"
if [ ! -f "${SERVICE_DESTINATION}"/"${SETUP_ENV_FILENAME}" ]; then
    cp -v "${SETUP_ENV_FULLPATH}" "${SERVICE_DESTINATION}"/"${SETUP_ENV_FILENAME}"
fi
HC_DC_BIN_PATH="${SERVICE_DESTINATION}"/bin
rsync -ar "${HC_PROGRAM_PATH}"/bin/ "${HC_DC_BIN_PATH}"/
HC_DC_ETC_PATH="${SERVICE_DESTINATION}"/etc
rsync -ar "${HC_PROGRAM_PATH}"/etc/ "${HC_DC_ETC_PATH}"/
HC_DC_ENV_FILE="${SERVICE_DESTINATION}"/docker-compose.${TARGET_ENV}.yml
cp -v "${HC_PROGRAM_PATH}"/docker-compose.yml "${SERVICE_DESTINATION}"/

# Setup LB config files
echo "Populate LB configurations ..."
mkdir -p "${APPS_BASE}"/lb/conf.d "${APPS_BASE}"/lb/certs
echo "  Sync up config files."
rsync -ar "${HC_CONF_SOURCE_PATH}"/lb/ "${APPS_BASE}"/lb/

PRIMARY_CERT_PATH=/certs/${PRIMARY_CERT_FILE:=fullchain.pem}
PRIMARY_PRIVATE_KEY_PATH=/certs/${PRIMARY_PRIVATE_KEY_FILE:=private.pem}
AUTHENTIK_CERT_PATH=/certs/${AUTHENTIK_CERT_FILE:=fullchain.pem}
AUTHENTIK_PRIVATE_KEY_PATH=/certs/${AUTHENTIK_PRIVATE_KEY_FILE:=private.pem}

echo "  Update config files."
for conf in "${APPS_BASE}"/lb/conf.d/*.conf
do
    for find_to_replace in PRIMARY_SERVER_NAME AUTHENTIK_SERVER_NAME PRIMARY_CERT_PATH AUTHENTIK_CERT_PATH PRIMARY_PRIVATE_KEY_PATH AUTHENTIK_PRIVATE_KEY_PATH HTTPS_PORT
    do
        sed -i '' "s|%${find_to_replace}%|${!find_to_replace}|g" "${conf}"
    done
done

echo "  Generate lb docker-compose config."
# Generate the docker-compose.<env>.yml
printf "services:\n" > "${HC_DC_ENV_FILE}"
# LB
{
    printf "\n";
    printf "  lb:\n";
    printf "    volumes:\n";
    printf "      - %s:/etc/nginx.conf\n" "${APPS_BASE}/lb/nginx.conf";
    printf "      - %s:/etc/nginx/conf.d\n" "${APPS_BASE}/lb/conf.d";
    printf "      - %s:/webroot\n" "${APPS_BASE}/lb/webroot";
    printf "      - %s:/certs\n" "${CERTIFICATE_PATH}";
} >> ${HC_DC_ENV_FILE}
echo ""

echo "Generate MariaDB docker-compose config."
# MariaDb
{
    printf "\n";
    printf "  mariadb:\n";
    printf "    volumes:\n";
    printf "      - %s:/var/lib/mysql\n" "${APPS_BASE}/mariadb";
} >> "${HC_DC_ENV_FILE}"
echo ""

echo "Generate PostgreSQL docker-compose config."
# PostgreSQL
{
    printf "\n";
    printf "  postgres:\n";
    printf "    volumes:\n";
    printf "      - %s:/var/lib/postgresql/data\n" "${APPS_BASE}/postgres";
} >> "${HC_DC_ENV_FILE}"
echo ""

echo "Generate Redis docker-compose config."
# Redis
{
    printf "\n";
    printf "  redis:\n";
    printf "    volumes:\n";
    printf "      - %s:/data\n" "${APPS_BASE}/redis";
} >> "${HC_DC_ENV_FILE}"
echo ""

echo "Generate Authentik configurations."
# Authentik Server
mkdir -p "${APPS_BASE}"/authentik/media "${APPS_BASE}"/authentik/templates "${APPS_BASE}"/authentik/data "${APPS_BASE}"/authentik/certs
echo "  Sync up config files."
rsync -ar "${HC_CONF_SOURCE_PATH}"/authentik/ "${APPS_BASE}"/authentik/
sed -i '' "s|%PRIMARY_SERVER_NAME%|${PRIMARY_SERVER_NAME}|g" "${APPS_BASE}/authentik/data/user_settings.py"
sed -i '' "s|%AUTHENTIK_SERVER_NAME%|${AUTHENTIK_SERVER_NAME}|g" "${APPS_BASE}/authentik/data/user_settings.py"
sed -i '' "s|%HTTPS_PORT%|${HTTPS_PORT}|g" "${APPS_BASE}/authentik/data/user_settings.py"

echo "  Generate authentik server(app) docker-compose config."
{
    printf "\n";
    printf "  authentikapp:\n";
    printf "    volumes:\n";
    printf "      - %s:/media\n" "${APPS_BASE}/authentik/media";
    printf "      - %s:/templates\n" "${APPS_BASE}/authentik/templates";
    printf "      - %s:/data/user_settings.py\n" "${APPS_BASE}/authentik/data/user_settings.py";
} >> "${HC_DC_ENV_FILE}"
echo ""

echo "  Generate authentik worker docker-compose config."
# Authentikworker
{
    printf "\n";
    printf "  authentikworker:\n";
    printf "    volumes:\n";
    printf "      - %s:/media\n" "${APPS_BASE}/authentik/media";
    printf "      - %s:/certs\n" "${APPS_BASE}/authentik/certs";
    printf "      - %s:/templates\n" "${APPS_BASE}/authentik/templates";
    printf "      - %s:/data/user_settings.py\n" "${APPS_BASE}/authentik/data/user_settings.py";
} >> "${HC_DC_ENV_FILE}"
echo ""

echo "Generate nextcloud app docker-compose config."
# nextcloudapp
{
    printf "\n";
    printf "  nextcloudapp:\n";
    printf "    volumes:\n";
    printf "      - %s:/var/www/html\n" "${APPS_BASE}/nextcloud";
    printf "      - %s:/var/www/html/data\n" "${DATA_BASE}/nextcloud";
} >> "${HC_DC_ENV_FILE}"
echo ""

echo "Generate nextcloud web docker-compose config."
# nextcloudweb
rsync -ar "${HC_CONF_SOURCE_PATH}"/nextcloud-web/ "${APPS_BASE}"/nextcloud-web/
{
    printf "\n";
    printf "  nextcloudweb:\n";
    printf "    volumes:\n";
    printf "      - %s:/etc/nginx/nginx.conf\n" "${APPS_BASE}/nextcloud-web/nginx.conf";
    printf "      - %s:/var/www/html:ro\n" "${APPS_BASE}/nextcloud";
} >> "${HC_DC_ENV_FILE}"
echo ""

echo "Generate nextcloud cron docker-compose config."
# nextcloudcron
{
    printf "\n";
    printf "  nextcloudcron:\n";
    printf "    volumes:\n";
    printf "      - %s:/var/www/html\n" "${APPS_BASE}/nextcloud";
    printf "      - %s:/var/www/html/data\n" "${DATA_BASE}/nextcloud";
} >> "${HC_DC_ENV_FILE}"
echo ""

# Populate docker container environment variables
echo "Generate CODE configurations."
CODE_ENV_TEMPLATE="${HC_PROGRAM_PATH}"/templates/code.env.template
CODE_ENV_FILE="${SERVICE_DESTINATION}"/code.${TARGET_ENV}
echo "  Copy and update env file code.${TARGET_ENV}"
cp -v "${CODE_ENV_TEMPLATE}" "${CODE_ENV_FILE}"
sed -i '' "s|%PRIMARY_SERVER_NAME%|${PRIMARY_SERVER_NAME}|g" "${CODE_ENV_FILE}"
sed -i '' "s|%HTTPS_PORT%|${HTTPS_PORT}|g" "${CODE_ENV_FILE}"
echo "  Generate CODE docker-compose config"
mkdir -p "${APPS_BASE}"/code/fonts
{
    printf "\n";
    printf "  code:\n";
    printf "    env_file: code.%s\n" "${TARGET_ENV}";
    printf "    volumes:\n";
    printf "      - %s:/opt/cool/systemplate/tmpfonts:rw\n" "${APPS_BASE}/code/fonts";
} >> "${HC_DC_ENV_FILE}"
echo ""

# clamav
echo "Generate ClamAV configuration."
{
    printf "\n";
    printf "  clamav:\n";
    printf "    volumes:\n";
    printf "      - %s:/var/lib/clamav:rw\n" "${APPS_BASE}/clamav";
} >> "${HC_DC_ENV_FILE}"
echo ""

# elasticsearch
echo "Generate ElasticSearch configuration."
mkdir -p "${APPS_BASE}"/elasticsearch/data
{
    printf "\n";
    printf "  elasticsearch:\n";
    printf "    volumes:\n";
    printf "      - %s:/usr/share/elasticsearch/data:rw\n" "${APPS_BASE}/elasticsearch/data";
} >> "${HC_DC_ENV_FILE}"
echo ""

# Prepare the secrets files
echo "Generate docker-compose secrets section"
echo "" >> "${HC_DC_ENV_FILE}"
"${HC_DC_BIN_PATH}"/vault.setup.sh -a "${VAULT_BASE}" >> "${HC_DC_ENV_FILE}"
echo ""

# Generate docker-compose operators
echo "Generate docker-compose operators."
DC_START_DBONLY="${HC_DC_BIN_PATH}/start.dbonly.sh"
DC_STOP_DBONLY="${HC_DC_BIN_PATH}/stop.dbonly.sh"
DC_START="${HC_DC_BIN_PATH}/start.sh"
DC_START_DAEMON="${HC_DC_BIN_PATH}/start.daemon.sh"
DC_STOP="${HC_DC_BIN_PATH}/stop.sh"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a start" > "${DC_START}"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a stop" > "${DC_STOP}"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a start -d" > "${DC_START_DAEMON}"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a start -b" > "${DC_START_DBONLY}"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a stop -b" > "${DC_STOP_DBONLY}"
chmod +x "${DC_START}" "${DC_STOP}" "${DC_START_DAEMON}" "${DC_START_DBONLY}" "${DC_STOP_DBONLY}"
echo ""

echo "Prepare deployment environment ${TARGET_ENV} Done!"