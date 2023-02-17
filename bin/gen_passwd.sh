#!/usr/bin/env bash

OS_NAME=$(uname)
if [ "${OS_NAME}" = "Darwin"  ]; then
    SHASUM="shasum -a 256"
    DATE_CMD=$(which gdate)
else
    SHASUM="sha256sum"
    DATE_CMD=$(which date)
fi

declare -i NUM_OF_PASSWD=32
if [ -n "$1" ]; then
    NUM_OF_PASSWD=$1
fi

if [ -x "${DATE_CMD}" ]; then
    ${DATE_CMD} +%s.%N | ${SHASUM} | base64 | head -c "${NUM_OF_PASSWD}"
fi
