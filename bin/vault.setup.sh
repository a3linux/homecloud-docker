#!/usr/bin/env bash
# Setup secrets files used by HomeCloud service
declare -A colors
colors[Color_Off]='\033[0m'
colors[Red]='\033[0;31m'
colors[Green]='\033[0;32m'
colors[Yellow]='\033[0;33m'
colors[Blue]='\033[0;34m'
colors[Purple]='\033[0;35m'
colors[Cyan]='\033[0;36m'
colors[White]='\033[0;37m'

VAULT_BASE_PATH=""
OUTPUT_COMPOSE_CONTENT="no"
# script path
mypath=$(realpath "${BASH_SOURCE:-$0}")
MYSELF_PATH=$(dirname "${mypath}")

SECRETS_FILES="
mariadb_root_password.txt
mariadb_bookstack_password.txt
postgres_psql_password.txt
postgres_authentik_password.txt
authentik_akadmin_password.txt
authentik_secret_key.txt
postgres_nextcloud_password.txt
nextcloud_admin_password.txt
calibreweb_admin_password.txt
talk_turn_secret.txt
talk_signaling_secret.txt
talk_internal_secret.txt
bookstack_admin_password.txt
"

usage() {
    echo -e "Usage: ${colors[Cyan]}$0 -a VAULT_PATH [-o]${colors[Color_Off]}"
    echo -e "    Generate or update secret files, if the secret file(s) already existed, the script will skip it."
}

error_exit() {
    usage
    exit 1
}

while getopts "a:oh" arg
do
    case ${arg} in
        a)
            VAULT_BASE_PATH=${OPTARG}
            ;;
        o)
            OUTPUT_COMPOSE_CONTENT="yes"
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${VAULT_BASE_PATH}" ]; then
    error_exit
fi

if [ ! -d "${VAULT_BASE_PATH}" ]; then
    echo -e "${colors[Red]}Vault path ${VAULT_BASE_PATH} does not exist!!${colors[Color_Off]}"
    exit 1
fi

for sf in ${SECRETS_FILES}
do
    if [ ! -f "${VAULT_BASE_PATH}"/"${sf}" ]; then
        "${MYSELF_PATH}"/gen_passwd.sh 50 > "${VAULT_BASE_PATH}"/"${sf}"
    fi
done

# Verbose: Output the docker-compose content of secrets
if [ "${OUTPUT_COMPOSE_CONTENT}" == "yes" ]; then
    printf "secrets:\n"
    for sf in ${SECRETS_FILES}
    do
        printf "  %s:\n" "${sf%%.txt}"
        printf "    file: %s/%s\n" "${VAULT_BASE_PATH}" "${sf}"
    done
fi
