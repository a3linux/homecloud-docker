#!/usr/bin/env bash
#
set -a
mypath=$(realpath "${BASH_SOURCE:-$0}")
MYSELF_PATH=$(dirname "${mypath}")

USERID=$(id -un)
SERVICE_DESTINATION="${MYSELF_PATH}/test/homecloud"
HOMECLOUD_ENV_FILE="${SERVICE_DESTINATION}/homecloud.test"
APPS_BASE="${MYSELF_PATH}/test/apps"
DATA_BASE="${MYSELF_PATH}/test/data"
VAULT_BASE="${MYSELF_PATH}/test/vault"
CERTIFICATE_PATH="${MYSELF_PATH}/test/apps/lb/certs"
TEMPLATER="${MYSELF_PATH}/templater.sh"
DEPLOYMENT_SH="${MYSELF_PATH}/deployment.sh"

mkdir -p "${SERVICE_DESTINATION}"
${TEMPLATER} "${MYSELF_PATH}/test/test.env" > "${HOMECLOUD_ENV_FILE}"

${DEPLOYMENT_SH} -c "${HOMECLOUD_ENV_FILE}"
ls ${SERVICE_DESTINATION} ${APPS_BASE} ${DATA_BASE} ${VAULT_BASE}
${DEPLOYMENT_SH} -c "${HOMECLOUD_ENV_FILE}"

rm -rf "${SERVICE_DESTINATION}" "${APPS_BASE}" "${DATA_BASE}" "${VAULT_BASE}"
