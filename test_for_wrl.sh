#!/bin/bash

PORT=5444
SCALE=800000
PGUSER=postgres
SCALEb4=$((SCALE/4))
WRLDELAY=100
NOWRLDELAY=0
LOG=logile
DATA=data
PGDB=postgres

#slows down CLUSTER, VACUUM FULL, ALTER TABLE (rewrite & set
#tablespace), CREATE INDEX


function init_tb
{
  bin/psql -U $PGUSER -p5444 -c 'show wal_rate_limit'

  bin/psql -U $PGUSER -p$PORT -c "CREATE TABLE tb_test \
                     AS SELECT i, \
                         round(random()*100),\
                         i*500 as high_int \
                     FROM generate_series(1, $SCALE) i(i); \
          ALTER TABLE tb_test SET (FILLFACTOR=60);\
          ALTER TABLE tb_test ADD PRIMARY KEY(i); \
          "   
  #bin/psql -U$USER -p5444 -c '\d+ tb_test'

  bin/psql -U $PGUSER -p5444 -c "UPDATE tb_test SET i = -i \
                    WHERE i IN (SELECT distinct(round(random()*10000)) \
                    FROM generate_series(1, $SCALEb4))"
}

function disable_wrl
{
  sed -i "s/wal_rate_limit = $WRLDELAY/wal_rate_limit = 0/" data/postgresql.conf
  su postgres -c "bin/pg_ctl -D$DATA reload"
}

function maintenance_1
{
  
  time bin/psql -U $PGUSER -p5444 -c "CLUSTER tb_test USING tb_test_pkey;"

  time bin/vacuumdb -f -U $PGUSER -p5444 -t tb_test $PGDB 

  time bin/psql -U$PGUSER -p5444 -c "CREATE INDEX ON tb_test(high_int)"

}

function check_wrl
{
  bin/psql -U $PGUSER -p5444 -c 'show wal_rate_limit'
}

function enable_wrl
{
  sed -i "s/wal_rate_limit = 0/wal_rate_limit = $WRLDELAY/" data/postgresql.conf
  su postgres -c "bin/pg_ctl -D$DATA reload"
   
}

function drop_tb
{
  bin/psql -U $PGUSER -p5444 -c 'DROP TABLE IF EXISTS tb_test'
}


init_tb
date > $LOG
maintenance_1 >> $LOG
date >> $LOG
drop_tb >> $LOG
uptime >> $LOG

sleep 30 

init_tb >> $LOG
enable_wrl >> $LOG
check_wrl >> $LOG
date >> $LOG
maintenance_1 >> $LOG
date >> $LOG
drop_tb >> $LOG
uptime >> $LOG

disable_wrl >> $LOG
