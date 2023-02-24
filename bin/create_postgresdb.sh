#!/usr/bin/env bash
# create_postgresdb.sh
VAULT_PATH=""
DBNAME=""
DBUSER=""
DBCONTAINER=""

usage() {
    echo "Usage: $0 -n DATABASE_NAME -u DATABASE_USER -s VAULT_PATH -d DATABASE_CONTAINER_NAME"
    echo "  Create an PostgreSQL database with DATABASE_NAME and grant all permission to DATABASE_USER"
    echo "  At least the homecloud dbonly should start."
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

DBPASSWD_FILE="postgres_${DBUSER}_password.txt"

if [ -f "${VAULT_PATH}/${DBPASSWD_FILE}" ]; then
    DBPASSWD=$(cat "${VAULT_PATH}/${DBPASSWD_FILE}")
else
    echo "${VAULT_PATH}/${DBPASSWD_FILE} not found, please add it first"
    error_exit
fi

docker exec -i "${DBCONTAINER}" createdb -U postgres "${DBNAME}";
docker exec -i "${DBCONTAINER}" psql -U postgres -c "CREATE USER ${DBUSER} WITH PASSWORD '${DBPASSWD}';"
docker exec -i "${DBCONTAINER}" psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DBNAME} TO ${DBUSER};"
# From PostgreSQL 15.0, the public schema permission changed.
docker exec -i "${DBCONTAINER}" psql -U postgres -c "ALTER DATABASE ${DBNAME} OWNER TO ${DBUSER};"
docker exec -i "${DBCONTAINER}" psql -U postgres -c "GRANT ALL ON SCHEMA public TO ${DBUSER};"
docker exec -i "${DBCONTAINER}" psql -U postgres -c "GRANT USAGE, CREATE ON SCHEMA public TO ${DBUSER};"
