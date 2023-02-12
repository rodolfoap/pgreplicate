# Replication in PostgreSQL

This is a simple example of database replication, based on https://www.youtube.com/watch?v=Yy0GJjRQcRQ.

The replication process is simple, and only PostgreSQL native tools are required.

## Usage (TLDR)

If you need to learn quick, just do:
```
$ docker-compose up -d
$ ./replicate.bash
```

There you have. Now you're an expert on replication.

## Usage

### Launch `docker-compose`

Launch two PostgreSQL containers, which will hold the replicated databases. The containers are:

* **publisher**  (holding the **dbpub** database)
* **subscriber** (holding the **dbsub** database)

Notice the only required configuration is `wal_level=logical`, which is defined in the `postgresql.conf` file. The docker image has a different way of setting it, though:

```
services:
  publisher:
    container_name: publisher
    image: postgres:11-alpine
    ....
    command: postgres -c wal_level=logical <------------- Here!
```

Containers are launched with `docker-compose`:

```
$ docker-compose up
```

### Configure and start replication


Once the containers are running, just run the command replicate.bash and read the output thoroughly:

```
$ ./replicate.bash
```

### Execution log

This is a typical execution log, which is just a copy of the output produced by the `./replicate.bash` command.

The only difference between both containers is the `wal_level` setting. On the Publisher:
```
+ docker exec -it publisher psql -U postgres -c "SELECT name, setting FROM pg_settings WHERE name='wal_level';"
   name    | setting
-----------+---------
 wal_level | logical
(1 row)
```

On the Subscriber:
```
+ docker exec -it subscriber psql -U postgres -c "SELECT name, setting FROM pg_settings WHERE name='wal_level';"
   name    | setting
-----------+---------
 wal_level | replica
(1 row)
```

On the PUBLISHER, where the database `dboriginal` already exists, we create one table, `table1` and populate it:
```
+ docker exec -it publisher psql -U postgres -d dboriginal -c "CREATE TABLE table1(id int PRIMARY KEY, name VARCHAR);"
CREATE TABLE
+ docker exec -it publisher psql -U postgres -d dboriginal -c "INSERT INTO table1 VALUES(generate_series(1,10), 'data'||generate_series(1,10));"
INSERT 0 10
```

Now, we transfer all STRUCTURE, not the data, from the database `dboriginal` on the PUBLISHER to the database `dbreplica` on the SUBSCRIBER:
```
+ docker exec -i publisher pg_dump -t table1 -s dboriginal -U postgres|docker exec -i subscriber psql -U postgres -d dbreplica;

SET
SET
SET
SET
SET
 set_config
------------

(1 row)

SET
SET
SET
SET
SET
SET
CREATE TABLE
ALTER TABLE
ALTER TABLE
```

We can see that the table exists on the PUBLISHER, with data:
```
+ docker exec -it publisher psql -U postgres -d dboriginal -c 'SELECT * FROM table1;'
 id |  name
----+--------
  1 | data1
  2 | data2
  3 | data3
  4 | data4
  5 | data5
  6 | data6
  7 | data7
  8 | data8
  9 | data9
 10 | data10
(10 rows)
```

We can see that the table exists on the SUBSCRIBER, but it has no data:
```
+ docker exec -it subscriber psql -U postgres -d dbreplica -c 'SELECT * FROM table1;'
 id | name
----+------
(0 rows)
```

Now, on the PUBLISHER, a PUBLICATION is created:
```
+ docker exec -it publisher psql -U postgres -d dboriginal -c 'CREATE PUBLICATION thesocket FOR ALL TABLES;'
CREATE PUBLICATION
```

And on the SUBSCRIBER, a SUBSCRIPTION is created:
```
+ docker exec -it subscriber psql -U postgres -d dbreplica -c "CREATE SUBSCRIPTION theplug CONNECTION 'dbname=dboriginal host=publisher user=postgres password=password' PUBLICATION thesocket;"
NOTICE:  created replication slot "theplug" on publisher
CREATE SUBSCRIPTION
```

If the `wal_level` option would not be correctly set on the PUBLISHER, you would get an error like this...
```
+ docker exec -it subscriber psql -U postgres -d dbreplica -c "CREATE SUBSCRIPTION theplug CONNECTION 'dbname=dboriginal host=publisher user=postgres password=password' PUBLICATION thesocket;"
ERROR:  could not create replication slot "theplug": ERROR:  logical decoding requires wal_level >= logical
```
... and obviously, there would be no replication.

Its the time to check if the SUBSCRIBER has data:
```
+ docker exec -it subscriber psql -U postgres -d dbreplica -c 'SELECT * FROM table1;'
 id |  name
----+--------
  1 | data1
  2 | data2
  3 | data3
  4 | data4
  5 | data5
  6 | data6
  7 | data7
  8 | data8
  9 | data9
 10 | data10
(10 rows)
```

And now, more data will be added on the PUBLISHER:
```
+ docker exec -it publisher psql -U postgres -d dboriginal -c "INSERT INTO table1 VALUES(generate_series(11,20), 'data'||generate_series(11,20));"
INSERT 0 10
```

This data should already be replicated on the SUBSCRIBER:
```
+ docker exec -it subscriber psql -U postgres -d dbreplica -c 'SELECT * FROM table1;'
 id |  name
----+--------
  1 | data1
  2 | data2
  3 | data3
  4 | data4
  5 | data5
  6 | data6
  7 | data7
  8 | data8
  9 | data9
 10 | data10
 11 | data11
 12 | data12
 13 | data13
 14 | data14
 15 | data15
 16 | data16
 17 | data17
 18 | data18
 19 | data19
 20 | data20
(20 rows)
```
