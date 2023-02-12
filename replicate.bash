#!/bin/bash

sql_publisher() { { set +x; } &>/dev/null; docker exec -it publisher  psql -U postgres -d dboriginal -c "${1}"; echo; set -x; }
sql_subscriber(){ { set +x; } &>/dev/null; docker exec -it subscriber psql -U postgres -d dbreplica  -c "${1}"; echo; set -x; }
set -x

: The only difference between both containers is this setting:
: On the Publisher, this have been set:
sql_publisher  "SELECT name, setting FROM pg_settings WHERE name='wal_level';"

: On the Subscriber, the default is kept:
sql_subscriber "SELECT name, setting FROM pg_settings WHERE name='wal_level';"

: On the PUBLISHER, where the database "dboriginal" already exists, we create one table "table1" and populate it:
sql_publisher  "CREATE TABLE table1(id int PRIMARY KEY, name VARCHAR);"
sql_publisher  "INSERT INTO table1 VALUES(generate_series(1,10), 'data'||generate_series(1,10));"

: Now, we transfer all STRUCTURE, not the data, from the database "dboriginal" on the PUBLISHER to the database "dbreplica" on the SUBSCRIBER:
docker exec -i publisher pg_dump -t table1 -s dboriginal -U postgres|docker exec -i subscriber psql -U postgres -d dbreplica;

: We can see that the table exists on the PUBLISHER, with data:
sql_publisher  "SELECT * FROM table1;"

: We can see that the table exists on the SUBSCRIBER, but it has no data:
sql_subscriber "SELECT * FROM table1;"

: Now, on the PUBLISHER, a PUBLICATION is created:
sql_publisher  "CREATE PUBLICATION thesocket FOR ALL TABLES;"

: And on the SUBSCRIBER, a SUBSCRIPTION is created:
sql_subscriber "CREATE SUBSCRIPTION theplug CONNECTION 'dbname=dboriginal host=publisher user=postgres password=password' PUBLICATION thesocket;"

: Its the time to check if the SUBSCRIBER has data:
sql_subscriber "SELECT * FROM table1;"

: And now, more data will be added on the PUBLISHER
sql_publisher  "INSERT INTO table1 VALUES(generate_series(11,20), 'data'||generate_series(11,20));"

: This data should already be replicated on the SUBSCRIBER:
sql_subscriber "SELECT * FROM table1;"
