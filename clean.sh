#!/bin/bash
su postgres -c 'bin/initdb -D data' && su postgres -c 'bin/pg_ctl -D data start'
echo "Sleeping 2 seconds"
sleep 2
bin/createdb -Upostgres test
bin/psql -Upostgres test < plpgsql_snippets/deparse_util.sql > >(tee stdout.log) 2> >(tee stderr.log >&2)
sleep 10
bin/dropdb -Upostgres test
su postgres -c 'bin/pg_ctl -D data stop'
rm -rf data
