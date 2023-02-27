#!/bin/bash
# Check a give file updated time, if the updated time less than n days, alert!


usage() {
    echo "Usage: $0 -f filename -n num -e email | -h"
    echo "  -f the filename to check"
    echo "  -n how many hours to set as new files, default 12 hours"
    echo "  -e alert email address"
    echo "  -h display this message"
}
error_exit() {
    usage
    exit 1
}

HOURS=12
while getopts "e:f::n:h" opt
do
    case $opt in
        f)
            FILENAME=${OPTARG}
            if [ ! -f "${FILENAME}" ]; then
                error_exit
            fi
            ;;
        n)
            HOURS=${OPTARG}
            ;;
        e)
            EMAIL=${OPTARG}
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done
shift $((OPTIND-1))


CTIME=$(date +%s)
LAST_MODIFIED=$(stat -c %Y "${FILENAME}")
HOURS_FROM_MODIFIED=$(( (CTIME - LAST_MODIFIED) / 3600 ))

if [ "${HOURS_FROM_MODIFIED}" -lt "${HOURS}" ]; then
    echo -e "Subject: File ${FILENAME} updated in ${HOURS} hours!\n\n ${FILENAME} is updated in ${HOURS} hours\n\n: Timestamp: $(date)\r\n" | msmtp "${EMAIL}"
fi
