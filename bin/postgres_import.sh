#!/usr/bin/env bash

docker exec -i homecloud_postgres psql -U postgres < "$1"
