#!/usr/bin/env bash
# Restore databases from full dump backup
DBTYPE="postgres"
DBCONTAINER="homecloud_postgres"
DBDUMPFILE=""
usage() {
    echo "Usage: $0 -e DATABASE_TYPE -d DATABASE_CONTAINER_NAME -i DATABASES_DUMP_FILE"
    echo "  -e DBTYPE, postgres | mariadb"
    echo "  -d DATABASE CONTAINER NAME"
    echo "  -i Databases dump file"
    echo "  Dump all databases from given database container"
}
error_exit() {
    usage
    exit 1
}

while getopts "e:d:i:h" opt
do
    case $opt in
        e)
            DBTYPE=${OPTARG}
            if [ "${DBTYPE}" != "postgres" ] && [ "${DBTYPE}" != "mariadb" ]; then
                echo "Database type can ONLY be postgres | mariadb"
                error_exit
            fi
            ;;
        d)
            DBCONTAINER=${OPTARG}
            ;;
        i)
            DBDUMPFILE=${OPTARG}
            if [ ! -f "${DBDUMPFILE}" ]; then
                echo "${DBDUMPFILE} does not exist, please check!!!"
                error_exit
            fi
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done
shift $((OPTIND-1))

case "${DBTYPE}" in
    postgres)
        docker exec -i "${DBCONTAINER}" psql -U postgres < "${DBDUMPFILE}"
        ;;
    mariadb)
        MARIADB_ROOT_PASSWD=$(docker exec -i "${DBCONTAINER}" cat /run/secrets/mariadb_root_password)
        if [ -z "${MARIADB_ROOT_PASSWD}" ]; then
            echo "Fail to fetch MariaDB root password from container ${DBCONTAINER}!"
            error_exit
        fi
        docker exec -i "${DBCONTAINER}" mariadb -uroot -p"$MARIADB_ROOT_PASSWD" < "${DBDUMPFILE}"
        ;;
esac
if [ $? -eq 0 ]; then
    echo "Restores all ${DBTYPE} databases from ${DBDUMPFILE} successfully!"
else
    echo "Failed to restore all ${DBTYPE} databases from ${DBDUMPFILE}!!!"
    echo "Please check and try again!"
    exit 126
fi
