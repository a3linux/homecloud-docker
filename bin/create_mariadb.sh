#!/usr/bin/env bash

VAULT_PATH=""
DBNAME=""
DBUSER=""
DBCONTAINER=""

usage() {
    echo "Usage: $0 -n DATABASE_NAME -u DATABASE_USER -s VAULT_PATH -d DATABASE_CONTAINER_NAME"
    echo "  Create an MariaDB database with DATABASE_NAME and grant all permission to DATABASE_USER"
}
error_exit() {
    usage
    exit 1
}

while getopts "n:u:s:d:h" opt
do
    case $opt in
        n)
            DBNAME=${OPTARG}
            ;;
        u)
            DBUSER=${OPTARG}
            ;;
        s)
            VAULT_PATH=${OPTARG}
            ;;
        d)
            DBCONTAINER=${OPTARG}
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${VAULT_PATH}" ] || [ -z "${DBNAME}" ] || [ -z "${DBUSER}" ] || [ -z "${DBCONTAINER}" ]; then
    error_exit
fi

DBPASSWD_FILE="mariadb_${DBUSER}_password.txt"
ROOT_SECRET_FILE="${VAULT_PATH}/mariadb_root_password.txt"

if [ -f "${ROOT_SECRET_FILE}" ]; then
    ROOT_PASSWD=$(cat "${ROOT_SECRET_FILE}")
else
    echo "${ROOT_SECRET_FILE} not found, please check!"
    error_exit
fi

if [ -f "${VAULT_PATH}/${DBPASSWD_FILE}" ]; then
    DBPASSWD=$(cat "${VAULT_PATH}"/"${DBPASSWD_FILE}")
else
    echo "${VAULT_PATH}/${DBPASSWD_FILE} not found, please add it first!!!"
    error_exit
fi

SQL_FILE=/tmp/$$.sql
rm -f ${SQL_FILE}
{
    printf "CREATE DATABASE %s CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\n" "${DBNAME}";
    printf "GRANT ALL PRIVILEGES ON %s.* TO \'%s\'@\'%%\' IDENTIFIED BY \'%s\';\n" "${DBNAME}" "${DBUSER}" "${DBPASSWD}";
} > ${SQL_FILE}

cat "${SQL_FILE}" | docker exec -i "${DBCONTAINER}" mariadb --user=root --password="${ROOT_PASSWD}"
rm -f ${SQL_FILE}
