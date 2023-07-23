#!/usr/bin/env bash
set -a
SETUP_ENV_FULLPATH=""
PROFILES=""
ADDITIONAL_COMPOSE_FILE="" # User append compose file
#EXTRA_COMPOSE_FILE="" # Customized compose file assigned from homecloud.<env>
declare -A colors
colors[Color_Off]='\033[0m'
colors[Red]='\033[0;31m'
colors[Green]='\033[0;32m'
colors[Yellow]='\033[0;33m'
colors[Blue]='\033[0;34m'
colors[Purple]='\033[0;35m'
colors[Cyan]='\033[0;36m'
colors[White]='\033[0;37m'

usage() {
    echo -e "Usage: ${colors[Cyan]}$0 -c some_path/homecloud.<env> -a <action> -f <additional_compose.yml> -b -c -t -d -o${colors[Color_Off]}"
    echo -e "  ${colors[Yellow]}Please provide the homecloud service environment file, e.g. some_path/homecloud.dev"
    echo -e "  You COULD create such file based on templates/homecloud.env.template"
    echo -e "  The filename should be homecloud.<env>, <env> indicates the deployment, can be dev | prod"
    echo -e "  -a <action>  start | stop | restart | pull"
    echo -e "  -b Database Only Docker-compose profile applied"
    echo -e "  -c configuration file e.g. homecloud.prod"
    echo -e "  -d Deattach mode"
    echo -e "  -f additional docker-compose yml file, MUST be in service folder"
    echo -e "  -h Display this message${colors[Color_Off]}"
}

error_exit() {
    usage
    exit 1
}

while getopts "f::c:a:bdh" arg
do
    case ${arg} in
        f)
            ADDITIONAL_COMPOSE_FILE=${OPTARG}
            ;;
        c)
            SETUP_ENV_FULLPATH=${OPTARG}
            ;;
        a)
            ACTION=${OPTARG}
            if  [ "${ACTION}" != "start" ] && [ "${ACTION}" != "stop" ] && [ "${ACTION}" != "restart" ] && [ "${ACTION}" != "pull" ]; then
                echo -e "${colors[Red]}Action can be ONLY start | stop | restart | pull${colors[Color_Off]}"
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
    PROFILES=" ${PROFILES} --profile coreservices"
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

if [ "$CALIBREWEB_ENABLED" == "yes" ]; then
    PROFILES=" ${PROFILES} --profile calibreweb "
fi

if [ "$JELLYFIN_ENABLED" == "yes" ]; then
    PROFILES=" ${PROFILES} --profile jellyfin "
fi

if [ "$BOOKSTACK_ENABLED" == "yes" ]; then
    PROFILES=" ${PROFILES} --profile bookstack "
fi

if [ -n "${ADDITIONAL_COMPOSE_FILE}" ]; then
    PROFILES=" -f ${ADDITIONAL_COMPOSE_FILE} ${PROFILES} "
fi

if [ -n "${EXTRA_COMPOSE_FILE}" ]; then
    PROFILES=" -f ${SERVICE_DESTINATION}/${EXTRA_COMPOSE_FILE} ${PROFILES}"
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
