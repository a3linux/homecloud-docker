#!/usr/bin/env bash
# Generate self signed HTTPS certificate

DNS_NAME=""

usage() {
    echo "Usage: $0 -n DNS_NAME -a DNS_ALIAS1,DNS_ALIAS2"
}
error_exit() {
    usage
    exit 1
}

while getopts "n:a:h" opt
do
    case ${opt} in
        n)
            DNS_NAME=${OPTARG}
            ;;
        a)
            set -f
            IFS=","
            array=($OPTARG)
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${DNS_NAME}" ]; then
    error_exit
fi

SUBJ_STR="/C=SG/ST=Singapore/L=Singapore/O=HomeCloud/OU=Home/CN=${DNS_NAME}"
ADDEXT_STR="subjectAltName=DNS:${DNS_NAME}"

if [ ${#array[@]} -gt 0 ]; then
    for i in "${array[@]}"
    do
        ADDEXT_STR="${ADDEXT_STR},DNS:${i}"
    done
fi

if [ "$(uname)" = "Darwin" ]; then
    OPENSSL_CMD="/usr/local/opt/openssl/bin/openssl"
else
    OPENSSL_CMD="openssl"
fi

${OPENSSL_CMD} req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout "${DNS_NAME}".key -out "${DNS_NAME}".crt -subj "${SUBJ_STR}" -addext "${ADDEXT_STR}"
# -subj "/CN=localhost"
# vim: filetype=vim
