#!/usr/bin/env bash
# Generate HomeCloud service volumes(mount to docker)
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
    echo -e "!!!Folder ${colors[Red]}${SERVICE_DESTINATION} ${colors[Color_Off]}does not exist or can not access!!!"
    error_exit
fi

APPs="
lb
mariadb
postgres
redis
authentik
nextcloud
nextcloud-app
nextcloud-web
nextcloud-appdata
code
clamav
elasticsearch
"
DATAs="
mariadb
postgres
nextcloud
"
DSTs="
bin
etc
"

echo ""
echo -e "${colors[Green]}Start prepare the HomeCloud deployment environment: ${colors[Blue]}${TARGET_ENV} ${colors[Color_Off]}"
echo ""

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

# myself path
mypath=$(realpath "${BASH_SOURCE:-$0}")
MYSELF_PATH=$(dirname "${mypath}")
HC_PROGRAM_PATH="${MYSELF_PATH%%\/bin}"
HC_CONF_SOURCE_PATH="${HC_PROGRAM_PATH}"/conf

echo -e "${colors[Cyan]}Copy global scripts, config files${colors[Color_Off]}"
if [ ! -f "${SERVICE_DESTINATION}"/"${SETUP_ENV_FILENAME}" ]; then
    # if the setup file is not in destination folder, copy it
    cp -vf "${SETUP_ENV_FULLPATH}" "${SERVICE_DESTINATION}"/"${SETUP_ENV_FILENAME}"
fi
HC_DC_BIN_PATH="${SERVICE_DESTINATION}"/bin
rsync -ar "${HC_PROGRAM_PATH}"/bin/ "${HC_DC_BIN_PATH}"/
HC_DC_ETC_PATH="${SERVICE_DESTINATION}"/etc
rsync -ar "${HC_PROGRAM_PATH}"/etc/ "${HC_DC_ETC_PATH}"/
sed -i -e "s|%SERVICE_DESTINATION%|${SERVICE_DESTINATION}|g" "${HC_DC_ETC_PATH}"/systemd/system/multi-user.target.wants/homecloud.service
sed -i -e "s|%SETUP_ENV_FILENAME%|${SETUP_ENV_FILENAME}|g" "${HC_DC_ETC_PATH}"/cron.daily/homecloud_backup
sed -i -e "s|%SERVICE_DESTINATION%|${SERVICE_DESTINATION}|g" "${HC_DC_ETC_PATH}"/cron.daily/homecloud_backup
sed -i -e "s|%DEPLOYMENT_USER%|${DEPLOYMENT_USER}|g" "${HC_DC_ETC_PATH}"/cron.daily/homecloud_backup
sed -i -e "s|%ALERT_EMAIL%|${ALERT_EMAIL}|g" "${HC_DC_ETC_PATH}"/cron.daily/homecloud_backup
sed -i -e "s|%SETUP_ENV_FILENAME%|${SETUP_ENV_FILENAME}|g" "${HC_DC_ETC_PATH}"/cron.hourly/homecloud_backup
sed -i -e "s|%SERVICE_DESTINATION%|${SERVICE_DESTINATION}|g" "${HC_DC_ETC_PATH}"/cron.hourly/homecloud_backup
sed -i -e "s|%DEPLOYMENT_USER%|${DEPLOYMENT_USER}|g" "${HC_DC_ETC_PATH}"/cron.hourly/homecloud_backup
sed -i -e "s|%ALERT_EMAIL%|${ALERT_EMAIL}|g" "${HC_DC_ETC_PATH}"/cron.hourly/homecloud_backup
chmod +x "${HC_DC_ETC_PATH}"/cron.hourly/homecloud_backup "${HC_DC_ETC_PATH}"/cron.daily/homecloud_backup
cp -vf "${HC_PROGRAM_PATH}"/docker-compose.yml "${SERVICE_DESTINATION}"/

# Generate the docker-compose.<env>.yml
echo -e "${colors[Cyan]}Re-populate ${SERVICE_DESTINATION}/docker-compose.${TARGET_ENV}.yml${colors[Color_Off]}"
HC_DC_ENV_FILE="${SERVICE_DESTINATION}"/docker-compose.${TARGET_ENV}.yml
printf "services:\n" > "${HC_DC_ENV_FILE}"
# Setup LB config files
echo -e "${colors[Cyan]}Populate LB configurations ...${colors[Color_Off]}"
mkdir -p "${APPS_BASE}"/lb/conf.d "${APPS_BASE}"/lb/certs
rsync -ar "${HC_CONF_SOURCE_PATH}"/lb/ "${APPS_BASE}"/lb/

PRIMARY_CERT_PATH=/certs/${PRIMARY_CERT_FILE:=fullchain.pem}
PRIMARY_PRIVATE_KEY_PATH=/certs/${PRIMARY_PRIVATE_KEY_FILE:=private.pem}
AUTHENTIK_CERT_PATH=/certs/${AUTHENTIK_CERT_FILE:=fullchain.pem}
AUTHENTIK_PRIVATE_KEY_PATH=/certs/${AUTHENTIK_PRIVATE_KEY_FILE:=private.pem}
CODE_CERT_PATH=/certs/${PRIMARY_CERT_FILE:=fullchain.pem}
CODE_PRIVATE_KEY_PATH=/certs/${PRIMARY_PRIVATE_KEY_FILE:=private.pem}

echo -e "  ${colors[Cyan]}Update config files${colors[Color_Off]}"
for conf in "${APPS_BASE}"/lb/conf.d/*.conf
do
    for find_to_replace in PRIMARY_SERVER_NAME AUTHENTIK_SERVER_NAME CODE_SERVER_NAME PRIMARY_CERT_PATH AUTHENTIK_CERT_PATH PRIMARY_PRIVATE_KEY_PATH AUTHENTIK_PRIVATE_KEY_PATH HTTPS_PORT CODE_CERT_PATH CODE_PRIVATE_KEY_PATH
    do
        sed -i -e "s|%${find_to_replace}%|${!find_to_replace}|g" "${conf}"
    done
done
if [ "${CODE_SERVER_ENABLED}" != "yes" ]; then
    # There might be no code container running
    rm -f "${APPS_BASE}"/lb/conf.d/*-code.conf
fi

echo -e "  ${colors[Cyan]}Generate lb docker-compose config${colors[Color_Off]}"
# LB
{
    printf "\n";
    printf "  lb:\n";
    printf "    ports:\n";
    printf "      - %s:80\n" "${HTTP_PORT}";
    printf "      - %s:443\n" "${HTTPS_PORT}";
    printf "    volumes:\n";
    printf "      - %s:/etc/nginx.conf\n" "${APPS_BASE}/lb/nginx.conf";
    printf "      - %s:/etc/nginx/conf.d\n" "${APPS_BASE}/lb/conf.d";
    printf "      - %s:/webroot\n" "${APPS_BASE}/lb/webroot";
    printf "      - %s:/certs\n" "${CERTIFICATE_PATH}";
} >> ${HC_DC_ENV_FILE}

echo -e "${colors[Cyan]}Generate MariaDB docker-compose config${colors[Color_Off]}"
# MariaDb
{
    printf "\n";
    printf "  mariadb:\n";
    printf "    volumes:\n";
    printf "      - %s:/var/lib/mysql\n" "${APPS_BASE}/mariadb";
} >> "${HC_DC_ENV_FILE}"

echo -e "${colors[Cyan]}Generate PostgreSQL docker-compose config${colors[Color_Off]}"
# PostgreSQL
{
    printf "\n";
    printf "  postgres:\n";
    printf "    volumes:\n";
    printf "      - %s:/var/lib/postgresql/data\n" "${APPS_BASE}/postgres";
} >> "${HC_DC_ENV_FILE}"

echo -e "${colors[Cyan]}Generate Redis docker-compose config${colors[Color_Off]}"
# Redis
{
    printf "\n";
    printf "  redis:\n";
    printf "    volumes:\n";
    printf "      - %s:/data\n" "${APPS_BASE}/redis";
} >> "${HC_DC_ENV_FILE}"

echo -e "${colors[Cyan]}Generate Authentik configurations${colors[Color_Off]}"
AUTHENTIK_ENV_TEMPLATE="${HC_PROGRAM_PATH}"/env_files/authentik.env
AUTHENTIK_ENV_FILE="${SERVICE_DESTINATION}"/authentik.${TARGET_ENV}
if [ -f "${AUTHENTIK_ENV_FILE}" ]; then
    # File existed, not the first time
    echo -e "   ${colors[Red]}${AUTHENTIK_ENV_FILE} ${colors[Yellow]}exists and will not update it to avoid configuration overwrite${colors[Color_Off]}"
    echo -e "${colors[Yellow]}   !!! Please check and update ${AUTHENTIK_ENV_FILE} based on ${AUTHENTIK_ENV_TEMPLATE} !!!${colors[Color_Off]}"
else
    echo -e "  ${colors[Cyan]}Copy and update env file authentik.${TARGET_ENV}${colors[Color_Off]}"
    cp -v "${AUTHENTIK_ENV_TEMPLATE}" "${AUTHENTIK_ENV_FILE}"
fi
# Authentik Server
mkdir -p "${APPS_BASE}"/authentik/media "${APPS_BASE}"/authentik/templates "${APPS_BASE}"/authentik/data "${APPS_BASE}"/authentik/certs "${APPS_BASE}"/authentik/dist/extra
echo -e "  ${colors[Cyan]}Sync up config files${colors[Color_Off]}"
rsync -ar "${HC_CONF_SOURCE_PATH}"/authentik/ "${APPS_BASE}"/authentik/
sed -i -e "s|%PRIMARY_SERVER_NAME%|${PRIMARY_SERVER_NAME}|g" "${APPS_BASE}/authentik/data/user_settings.py"
sed -i -e "s|%AUTHENTIK_SERVER_NAME%|${AUTHENTIK_SERVER_NAME}|g" "${APPS_BASE}/authentik/data/user_settings.py"
sed -i -e "s|%HTTPS_PORT%|${HTTPS_PORT}|g" "${APPS_BASE}/authentik/data/user_settings.py"

echo -e "  ${colors[Cyan]}Generate authentik server(app) docker-compose config${colors[Color_Off]}"
if [ "${AUTHENTIK_ENV_FILE_ENABLED}" == "yes" ]; then
{
    printf "\n";
    printf "  authentikapp:\n";
    printf "    env_file: authentik.%s\n" "${TARGET_ENV}"
    printf "    volumes:\n";
    printf "      - %s:/media\n" "${APPS_BASE}/authentik/media";
    printf "      - %s:/templates\n" "${APPS_BASE}/authentik/templates";
    printf "      - %s:/data/user_settings.py:ro\n" "${APPS_BASE}/authentik/data/user_settings.py";
} >> "${HC_DC_ENV_FILE}"
else
{
    printf "\n";
    printf "  authentikapp:\n";
    printf "    volumes:\n";
    printf "      - %s:/media\n" "${APPS_BASE}/authentik/media";
    printf "      - %s:/templates\n" "${APPS_BASE}/authentik/templates";
    printf "      - %s:/data/user_settings.py:ro\n" "${APPS_BASE}/authentik/data/user_settings.py";
} >> "${HC_DC_ENV_FILE}"
fi
    #printf "      - %s:/web/dist/custom.css:ro\n" "${APPS_BASE}/authentik/dist/custom.css";
    #printf "      - %s:/web/dist/extra:ro\n" "${APPS_BASE}/authentik/dist/extra";

echo -e "  ${colors[Cyan]}Generate authentik worker docker-compose config${colors[Color_Off]}"
# Authentikworker
if [ "${AUTHENTIK_ENV_FILE_ENABLED}" == "yes" ]; then
{
    printf "\n";
    printf "  authentikworker:\n";
    printf "    env_file: authentik.%s\n" "${TARGET_ENV}"
    printf "    volumes:\n";
    printf "      - %s:/media\n" "${APPS_BASE}/authentik/media";
    printf "      - %s:/certs\n" "${APPS_BASE}/authentik/certs";
    printf "      - %s:/templates\n" "${APPS_BASE}/authentik/templates";
    printf "      - %s:/data/user_settings.py\n" "${APPS_BASE}/authentik/data/user_settings.py";
} >> "${HC_DC_ENV_FILE}"
else
{
    printf "\n";
    printf "  authentikworker:\n";
    printf "    volumes:\n";
    printf "      - %s:/media\n" "${APPS_BASE}/authentik/media";
    printf "      - %s:/certs\n" "${APPS_BASE}/authentik/certs";
    printf "      - %s:/templates\n" "${APPS_BASE}/authentik/templates";
    printf "      - %s:/data/user_settings.py\n" "${APPS_BASE}/authentik/data/user_settings.py";
} >> "${HC_DC_ENV_FILE}"
fi

rsync -ar "${HC_CONF_SOURCE_PATH}"/nextcloud-app/ "${APPS_BASE}"/nextcloud-app/
echo -e "${colors[Cyan]}Generate nextcloud app docker-compose config${colors[Color_Off]}"
# nextcloudapp
{
    printf "\n";
    printf "  nextcloudapp:\n";
    printf "    volumes:\n";
    printf "      - %s:/var/www/html\n" "${APPS_BASE}/nextcloud";
    printf "      - %s:/usr/local/etc/php-fpm.d/www.conf:ro\n" "${APPS_BASE}/nextcloud-app/www.conf";
    printf "      - %s:/var/www/html/data\n" "${DATA_BASE}/nextcloud";
} >> "${HC_DC_ENV_FILE}"

echo -e "${colors[Cyan]}Generate nextcloud web docker-compose config${colors[Color_Off]}"
# nextcloudweb
rsync -ar "${HC_CONF_SOURCE_PATH}"/nextcloud-web/ "${APPS_BASE}"/nextcloud-web/
{
    printf "\n";
    printf "  nextcloudweb:\n";
    printf "    volumes:\n";
    printf "      - %s:/etc/nginx/nginx.conf\n" "${APPS_BASE}/nextcloud-web/nginx.conf";
    printf "      - %s:/var/www/html:ro\n" "${APPS_BASE}/nextcloud";
} >> "${HC_DC_ENV_FILE}"

echo -e "${colors[Cyan]}Generate nextcloud cron docker-compose config${colors[Color_Off]}"
# nextcloudcron
{
    printf "\n";
    printf "  nextcloudcron:\n";
    printf "    volumes:\n";
    printf "      - %s:/var/www/html\n" "${APPS_BASE}/nextcloud";
    printf "      - %s:/var/www/html/data\n" "${DATA_BASE}/nextcloud";
} >> "${HC_DC_ENV_FILE}"

# Populate docker container environment variables
echo -e "${colors[Cyan]}Generate CODE configurations${colors[Color_Off]}"
CODE_ENV_TEMPLATE="${HC_PROGRAM_PATH}"/env_files/code.env
CODE_ENV_FILE="${SERVICE_DESTINATION}"/code.${TARGET_ENV}
echo -e "  ${colors[Cyan]}Copy and update env file code.${TARGET_ENV}${colors[Color_Off]}"
cp -v "${CODE_ENV_TEMPLATE}" "${CODE_ENV_FILE}"
sed -i -e "s|%PRIMARY_SERVER_NAME%|${PRIMARY_SERVER_NAME}|g" "${CODE_ENV_FILE}"
sed -i -e "s|%HTTPS_PORT%|${HTTPS_PORT}|g" "${CODE_ENV_FILE}"
echo -e "  ${colors[Cyan]}Generate CODE docker-compose config${colors[Color_Off]}"
mkdir -p "${APPS_BASE}"/code/fonts

if [ "${CODE_SERVER_ENABLED}" == "yes" ]; then
{
    printf "\n";
    printf "  code:\n";
    printf "    env_file: code.%s\n" "${TARGET_ENV}";
    printf "    volumes:\n";
    printf "      - %s:/opt/cool/systemplate/tmpfonts:rw\n" "${APPS_BASE}/code/fonts";
} >> "${HC_DC_ENV_FILE}"
fi

# clamav
echo -e "${colors[Cyan]}Generate ClamAV configuration${colors[Color_Off]}"
{
    printf "\n";
    printf "  clamav:\n";
    printf "    volumes:\n";
    printf "      - %s:/var/lib/clamav:rw\n" "${APPS_BASE}/clamav";
} >> "${HC_DC_ENV_FILE}"

# elasticsearch
echo -e "${colors[Cyan]}Generate ElasticSearch configuration${colors[Color_Off]}"
mkdir -p "${APPS_BASE}"/elasticsearch/data
{
    printf "\n";
    printf "  elasticsearch:\n";
    printf "    volumes:\n";
    printf "      - %s:/usr/share/elasticsearch/data:rw\n" "${APPS_BASE}/elasticsearch/data";
} >> "${HC_DC_ENV_FILE}"

# Prepare the secrets files
echo -e "${colors[Cyan]}Generate docker-compose secrets section${colors[Color_Off]}"
echo "" >> "${HC_DC_ENV_FILE}"
"${HC_DC_BIN_PATH}"/vault.setup.sh -a "${VAULT_BASE}" >> "${HC_DC_ENV_FILE}"

# Generate docker-compose operators
echo -e "${colors[Cyan]}Generate docker-compose maintenance scripts${colors[Color_Off]}"
DC_START_DBONLY="${HC_DC_BIN_PATH}/start.dbonly.sh"
DC_STOP_DBONLY="${HC_DC_BIN_PATH}/stop.dbonly.sh"
DC_START="${HC_DC_BIN_PATH}/start.sh"
DC_RESTART="${HC_DC_BIN_PATH}/restart.sh"
DC_START_DAEMON="${HC_DC_BIN_PATH}/start.daemon.sh"
DC_STOP="${HC_DC_BIN_PATH}/stop.sh"
DC_PULL="${HC_DC_BIN_PATH}/pull.sh"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a start" > "${DC_START}"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a restart" > "${DC_RESTART}"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a stop" > "${DC_STOP}"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a start -d" > "${DC_START_DAEMON}"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a start -b" > "${DC_START_DBONLY}"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a stop -b" > "${DC_STOP_DBONLY}"
echo "${HC_DC_BIN_PATH}/homecloud-service.sh -c ${SERVICE_DESTINATION}/${SETUP_ENV_FILENAME} -a pull" > "${DC_PULL}"
chmod +x "${DC_START}" "${DC_STOP}" "${DC_START_DAEMON}" "${DC_START_DBONLY}" "${DC_STOP_DBONLY}" "${DC_RESTART}" "${DC_PULL}"

# Generate create_databases.sh
echo -e "${colors[Cyan]}Generate Database scripts for first time setup${colors[Color_Off]}"
CREATE_DATABASES="${HC_DC_BIN_PATH}/create_databases.sh"
CREATE_POSTGRES="${HC_DC_BIN_PATH}/create_postgresdb.sh"
CREATE_MARIADB="${HC_DC_BIN_PATH}/create_mariadb.sh"

echo "#!/usr/bin/env bash" > "${CREATE_DATABASES}"
# PostgreSQL
if [ -x "${CREATE_POSTGRES}" ]; then
    echo "${CREATE_POSTGRES} -n authentik -u authentik -s ${VAULT_BASE} -d homecloud_postgres"  >> "${CREATE_DATABASES}"
    echo "${CREATE_POSTGRES} -n nextcloud -u nextcloud -s ${VAULT_BASE} -d homecloud_postgres" >> "${CREATE_DATABASES}"
fi
# MariaDB
if [ -x "${CREATE_MARIADB}" ]; then
    echo "  No mariadb to create!"
fi
chmod +x "${CREATE_DATABASES}"

if [ "$(uname)" == "Darwin" ]; then
    echo -e "${colors[Cyan]}Clean up bak files left by Sed on MacOS${colors[Color_Off]}"
    # Fix for MacOS sed https://unix.stackexchange.com/questions/13711/differences-between-sed-on-mac-osx-and-other-standard-sed
    find "${SERVICE_DESTINATION}" -name "*\-e" -exec rm -f {} \;
    find "${APPS_BASE}" -name "*\-e" -exec rm -f {} \;
fi

echo -e "${colors[Green]}Complete prepare HomeCloud deployment environment ${colors[Blue]}${TARGET_ENV}${colors[Color_Off]}"
