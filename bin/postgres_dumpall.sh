#!/usr/bin/env bash
DATE_STR=$(date +%Y%m%d_%H)
DUMP_FILENAME="postgres_dump.${DATE_STR}.sql"
docker exec -i homecloud_postgres /usr/bin/pg_dumpall -U postgres > "${DUMP_FILENAME}"
bzip2 "${DUMP_FILENAME}"
