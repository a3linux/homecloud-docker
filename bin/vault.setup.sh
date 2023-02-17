#!/usr/bin/env bash
# Setup secrets files used by HomeCloud service

VAULT_BASE_PATH=""

# script path
mypath=$(realpath "${BASH_SOURCE:-$0}")
MYSELF_PATH=$(dirname "${mypath}")

SECRETS_FILES="
mariadb_root_password.txt
postgres_psql_password.txt
postgres_authentik_password.txt
authentik_secret_key.txt
postgres_nextcloud_password.txt
nextcloud_admin_password.txt
"

usage() {
    echo "Usage: $0 -a VAULT_PATH"
}

error_exit() {
    usage
    exit 1
}

while getopts "a:h" arg
do
    case ${arg} in
        a)
            VAULT_BASE_PATH=${OPTARG}
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
    echo "Vault path ${VAULT_BASE_PATH} does not exist!!!!"
    exit 1
fi

for sf in ${SECRETS_FILES}
do
    if [ ! -f "${VAULT_BASE_PATH}"/"${sf}" ]; then
        "${MYSELF_PATH}"/gen_passwd.sh 50 > "${VAULT_BASE_PATH}"/"${sf}"
    fi
done

# Generate docker-compose.secrets.yml
printf "secrets:\n"
for sf in ${SECRETS_FILES}
do
    printf "  %s:\n" "${sf%%.txt}"
    printf "    file: %s/%s\n" "${VAULT_BASE_PATH}" "${sf}"
done
