#!/usr/bin/env bash

SECRET_FILE_PATH=""
DBNAME=""
DBUSER=""
DBCONTAINER=""

usage() {
    echo "Usage: $0 -n DATABASE_NAME -u DATABASE_USER -s SECRET_FILE_PATH -d DATABASE_CONTAINER"
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
            SECRET_FILE_PATH=${OPTARG}
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

if [ -z "${SECRET_FILE_PATH}" ] || [ -z "${DBNAME}" ] || [ -z "${DBUSER}" ] || [ -z "${DBCONTAINER}" ]; then
    error_exit
fi

DBPASSWD_FILE="postgres_${DBUSER}_password.txt"

if [ -f "${SECRET_FILE_PATH}/${DBPASSWD_FILE}" ]; then
    DBPASSWD=$(cat "${SECRET_FILE_PATH}/${DBPASSWD_FILE}")
else
    echo "${SECRET_FILE_PATH}/${DBPASSWD_FILE} not found, please add it first"
    error_exit
fi

docker exec -i "${DBCONTAINER}" createdb -U postgres "${DBNAME}";
docker exec -i "${DBCONTAINER}" psql -U postgres -c "CREATE USER ${DBUSER} WITH PASSWORD '${DBPASSWD}';"
docker exec -i "${DBCONTAINER}" psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DBNAME} TO ${DBUSER};"
