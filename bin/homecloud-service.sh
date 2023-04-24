#!/usr/bin/env bash
SETUP_ENV_FULLPATH=""
PROFILES=""
ADDITONAL_COMPOSE_FILE=""
usage() {
    echo "Usage: $0 -c some_path/homecloud.<env> -a <action> -f <additional_compose.yml> -b -c -t -d -o"
    echo "  Please provide the homecloud service environment file, e.g. some_path/homecloud.dev"
    echo "  You COULD create such file based on templates/homecloud.env.template"
    echo "  The filename should be homecloud.<env>, <env> indicates the deployment, can be dev | prod"
    echo "  -a <action>  start | stop | restart | pull"
    echo "  -b Database Only Docker-compose profile applied"
    echo "  -c configuration file e.g. homecloud.prod"
    echo "  -d Deattach mode"
    echo "  -f additional docker-compose yml file, MUST be in service folder"
    echo "  -h Display this message"
}

error_exit() {
    usage
    exit 1
}

while getopts "f::c:a:bdh" arg
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
            if  [ "${ACTION}" != "start" ] && [ "${ACTION}" != "stop" ] && [ "${ACTION}" != "restart" ] && [ "${ACTION}" != "pull" ]; then
                echo "Action can be ONLY start | stop | restart | pull"
                error_exit
            fi
            ;;
        d)
            IS_DEATTACHED="yes"
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

if [ "$CODE_SERVER_ENABLED" == "yes" ]; then
    PROFILES=" ${PROFILES} --profile code "
fi

if [ "$TALK_SERVER_ENABLED" == "yes" ]; then
    PROFILES=" ${PROFILES} --profile talk "
fi

if [ "$CLAMAV_SERVER_ENABLED" == "yes" ]; then
    PROFILES=" ${PROFILES} --profile clamav "
fi

if [ "$CALIBRE_WEB_ENABLED" == "yes" ]; then
    PROFILES=" ${PROFILES} --profile calibreweb "
fi

if [ -n "${ADDITONAL_COMPOSE_FILE}" ]; then
    PROFILES=" -f ${ADDITONAL_COMPOSE_FILE} ${PROFILES} "
fi

DOCKER_CMD=$(which docker||true)
DOCKER_COMPOSE_CMD=$(which docker-compose||true)
EXECUTOR_CMD=""

if [[ -n ${DOCKER_COMPOSE_CMD} ]] && [[ -x ${DOCKER_COMPOSE_CMD} ]]; then
    EXECUTOR_CMD=${DOCKER_COMPOSE_CMD}
elif [[ -n ${DOCKER_CMD} ]] && [[ -x ${DOCKER_CMD} ]]; then
    EXECUTOR_CMD="${DOCKER_CMD} compose "
else
    EXECUTOR_CMD="docker compose "
fi

case "${ACTION}" in
    start)
        if [ "${IS_DEATTACHED}" == "yes" ]; then
            ${EXECUTOR_CMD} -f ${SERVICE_DESTINATION}/docker-compose.yml -f ${SERVICE_DESTINATION}/docker-compose.${TARGET_ENV}.yml ${PROFILES} up -d
        else
            ${EXECUTOR_CMD} -f ${SERVICE_DESTINATION}/docker-compose.yml -f ${SERVICE_DESTINATION}/docker-compose.${TARGET_ENV}.yml ${PROFILES} up
        fi
        ;;
    restart)
        ${EXECUTOR_CMD} -f ${SERVICE_DESTINATION}/docker-compose.yml -f ${SERVICE_DESTINATION}/docker-compose.${TARGET_ENV}.yml ${PROFILES} restart
        ;;
    stop)
        ${EXECUTOR_CMD} -f ${SERVICE_DESTINATION}/docker-compose.yml -f ${SERVICE_DESTINATION}/docker-compose.${TARGET_ENV}.yml ${PROFILES} down
        ;;
    pull)
        ${EXECUTOR_CMD} -f ${SERVICE_DESTINATION}/docker-compose.yml -f ${SERVICE_DESTINATION}/docker-compose.${TARGET_ENV}.yml ${PROFILES} pull
        ;;
    *)
        error_exit
        ;;
esac
