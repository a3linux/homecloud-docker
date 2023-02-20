#!/usr/bin/env bash
SETUP_ENV_FULLPATH=""
PROFILES=""
ADDITONAL_COMPOSE_FILE=""
usage() {
    echo "Usage: $0 -c some_path/homecloud.<env> -a <action> -f <additional_compose.yml> -b -c -t -d"
    echo "  Please provide the homecloud service environment file, e.g. some_path/homecloud.dev"
    echo "  You COULD create such file based on templates/homecloud.env.template"
    echo "  The filename should be homecloud.<env>, <env> indicates the deployment, can be dev | prod"
    echo "  -a <action>  start | stop | restart"
    echo "  -b Database Only Docker-compose profile applied"
    echo "  -v Append clamav profile"
    echo "  -t Append talk profile"
    echo "  -d Deattach mode"
    echo "  -f additional docker-compose yml file, MUST be in service folder"
    echo "  -h Display this message"
}

error_exit() {
    usage
    exit 1
}

while getopts "f::c:a:vdbth" arg
do
    case ${arg} in
        f)
            ADDITONAL_COMPOSE_FILE=${OPTARG}
            ;;
        c)
            SETUP_ENV_FULLPATH=${OPTARG}
            ;;
        a)
            ACTION=${OPTARG}
            if  [ "${ACTION}" != "start" ] && [ "${ACTION}" != "stop" ] && [ "${ACTION}" != "restart" ]; then
                echo "Action can be ONLY start | stop | restart"
                error_exit
            fi
            ;;
        d)
            IS_DEATTACHED="yes"
            ;;
        v)
            PROFILES=" ${PROFILES} --profile clamav "
            ;;
        t)
            PROFILES=" ${PROFILES} --profile talk "
            ;;
        b)
            IS_DBONLY="yes"
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

if [ "${IS_DBONLY}" == "yes" ]; then
    PROFILES=" --profile dbonly "
else
    PROFILES=" ${PROFILES} --profile ${TARGET_ENV}"
fi

if [ ! -z "${ADDITONAL_COMPOSE_FILE}" ]; then
    PROFILES=" -f ${ADDITONAL_COMPOSE_FILE} ${PROFILES}"
fi

case "${ACTION}" in
    start)
        if [ "${IS_DEATTACHED}" == "yes" ]; then
            docker compose -f ${SERVICE_DESTINATION}/docker-compose.yml -f ${SERVICE_DESTINATION}/docker-compose.${TARGET_ENV}.yml ${PROFILES} up -d
        else
            docker compose -f ${SERVICE_DESTINATION}/docker-compose.yml -f ${SERVICE_DESTINATION}/docker-compose.${TARGET_ENV}.yml ${PROFILES} up
        fi
        ;;
    restart)
            docker compose -f ${SERVICE_DESTINATION}/docker-compose.yml -f ${SERVICE_DESTINATION}/docker-compose.${TARGET_ENV}.yml ${PROFILES} restart
        ;;
    stop)
            docker compose -f ${SERVICE_DESTINATION}/docker-compose.yml -f ${SERVICE_DESTINATION}/docker-compose.${TARGET_ENV}.yml ${PROFILES} down
        ;;
    *)
        error_exit
        ;;
esac
