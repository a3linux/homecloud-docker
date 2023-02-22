#!/usr/bin/env bash
# Dump all databases from a given database container
DBTYPE="postgres"
DBCONTAINER="homecloud_postgres"
DST_PATH="."
usage() {
    echo "Usage: $0 -e DATABASE_TYPE -d DATABASE_CONTAINER_NAME -o DST_FOLDER"
    echo "  -e DBTYPE, postgres | mariadb"
    echo "  -d DATABASE CONTAINER NAME"
    echo "  -o Destination folder to save dump file"
    echo "  Dump all databases from given database container"
}
error_exit() {
    usage
    exit 1
}

while getopts "e:d:o:h" opt
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
        o)
            DST_PATH=${OPTARG}
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done
shift $((OPTIND-1))

DATE_STR=$(date +%Y%m%d_%H)
DUMP_FILENAME="${DBTYPE}.all.${DATE_STR}.sql"
DUMP_FILE_FULLPATH="${DST_PATH}"/"${DUMP_FILENAME}"

case "${DBTYPE}" in
    postgres)
        docker exec -i "${DBCONTAINER}" /usr/local/bin/pg_dumpall -U postgres > "${DUMP_FILE_FULLPATH}"
        if [ $? -eq 0 ]; then
            echo "All ${DBTYPE} databases from container ${DBCONTAINER} dump to ${DUMP_FILE_FULLPATH} succesfully!"
        else
            echo "Failed to dump all ${DBTYPE} databases from container ${DBCONTAINER} to ${DUMP_FILE_FULLPATH}!!!"
            error_exit
        fi
        ;;
    mariadb)
        MARIADB_ROOT_PASSWD=`docker exec -i "${DBCONTAINER}" cat /run/secrets/mariadb_root_password`
        if [ -z "${MARIADB_ROOT_PASSWD}" ]; then
            echo "Fail to fetch MariaDB root password from container ${DBCONTAINER}!"
            error_exit
        fi
        docker exec -i "${DBCONTAINER}" mariadb-dump --all-databases -uroot -p"$MARIADB_ROOT_PASSWD" > "${DUMP_FILE_FULLPATH}"
        if [ $? -eq 0 ]; then
            echo "All ${DBTYPE} databases from container ${DBCONTAINER} dump to ${DUMP_FILE_FULLPATH} succesfully!"
        else
            echo "Failed to dump all ${DBTYPE} databases from container ${DBCONTAINER} to ${DUMP_FILE_FULLPATH}!!!"
            error_exit
        fi
        ;;
esac

echo "Compressing database dump."
bzip2 "${DUMP_FILE_FULLPATH}"
