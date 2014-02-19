-- root@precise64:/opt/event_trig_pg# mkdir /tmp/event_db
-- root@precise64:/opt/event_trig_pg# chown postgres: /tmp/event_db

\c postgres
DROP DATABASE event;
CREATE DATABASE event;
CREATE TABLESPACE event_db LOCATION '/tmp/event_db';

\c event

-- Log table
CREATE TABLE IF NOT EXISTS log (
  stamp timestamp,
  text_command text,
  text_expanded text
);

-- General execution to debug the command contents.
CREATE OR REPLACE FUNCTION snitch() RETURNS event_trigger LANGUAGE
plpgsql AS $$
DECLARE
        r RECORD;
BEGIN
        RAISE NOTICE 'Trigger has been executed. % -- %  ', TG_EVENT, TG_TAG ;
        FOR r IN SELECT * FROM pg_event_trigger_get_creation_commands()
        LOOP
                INSERT INTO log VALUES (now(), r.command::text, pg_event_trigger_expand_command(r.command::json)::text);
                RAISE NOTICE 'JSON blob: %', r.command;
                RAISE NOTICE 'expanded: %',  pg_event_trigger_expand_command(r.command::json);
        END LOOP;
END;
$$;

-- Create a user for the tests
-- CREATE USER IF NOT EXISTS event_user;



-- Schema test
-- Syntax:
-- CREATE SCHEMA schema_name [ AUTHORIZATION user_name ] [ schema_element [ ... ] ]
-- CREATE SCHEMA AUTHORIZATION user_name [ schema_element [ ... ] ]
-- CREATE SCHEMA IF NOT EXISTS schema_name [ AUTHORIZATION user_name ]
-- CREATE SCHEMA IF NOT EXISTS AUTHORIZATION user_name


CREATE EVENT TRIGGER before_create_schema ON ddl_command_start WHEN TAG IN ('create schema') EXECUTE PROCEDURE snitch();
CREATE EVENT TRIGGER after_create_schema ON ddl_command_end WHEN TAG IN ('create schema') EXECUTE PROCEDURE snitch();
CREATE EVENT TRIGGER drop_schema         ON sql_drop        WHEN TAG IN ('drop schema') EXECUTE PROCEDURE snitch();

-- list event triggers
\dy

CREATE SCHEMA test_1;
CREATE SCHEMA test_2 AUTHORIZATION event_user;
CREATE SCHEMA AUTHORIZATION event_user;
CREATE SCHEMA IF NOT EXISTS test_3;
CREATE SCHEMA IF NOT EXISTS test_3; -- It exists
CREATE SCHEMA IF NOT EXISTS test_3 AUTHORIZATION event_user; -- already exists
CREATE SCHEMA IF NOT EXISTS test_4;
CREATE SCHEMA IF NOT EXISTS test_5;

-- list schemas
\dn

DROP SCHEMA test_1;
DROP SCHEMA test_1; -- Should fail
DROP SCHEMA test_2;
DROP SCHEMA test_3;
DROP SCHEMA test_4;
DROP SCHEMA test_5;
DROP SCHEMA event_user;
DROP EVENT TRIGGER IF EXISTS before_create_schema RESTRICT;
DROP EVENT TRIGGER IF EXISTS after_create_schema RESTRICT;
DROP EVENT TRIGGER IF EXISTS drop_schema;



--
-- Table check
--


CREATE EVENT TRIGGER before_create_table ON ddl_command_start WHEN TAG IN ('create table','create index') EXECUTE PROCEDURE snitch();
CREATE EVENT TRIGGER after_create_table ON ddl_command_end WHEN TAG IN ('create table', 'create index') EXECUTE PROCEDURE snitch();
CREATE EVENT TRIGGER drop_table         ON sql_drop        WHEN TAG IN ('drop table', 'drop index') EXECUTE PROCEDURE snitch();


CREATE TABLE foo (a int PRIMARY KEY) TABLESPACE event_db;
CREATE TABLE bar (b timestamptz(3), c char, LIKE foo) WITH (autovacuum_enabled=off);
CREATE TABLE baz (d decimal(10, 4), e SERIAL, p point) INHERITS (bar);
CREATE TABLE nyan AS SELECT * FROM foo;

CREATE TABLE bar2 (b timestamptz(3), c char, LIKE foo INCLUDING ALL) INHERITS (bar) WITH  OIDS;

CREATE TABLE only_like (LIKE foo INCLUDING ALL);
CREATE TABLE only_tz (o timestamptz);

--\q

-- 
-- Index Check
--

--CREATE [ UNIQUE ] INDEX [ CONCURRENTLY ] [ name ] ON table_name [ USING method ]
--    ( { column_name | ( expression ) } [ COLLATE collation ] [ opclass ] [ ASC | DESC ] [ NULLS { FIRST | LAST } ] [, ...] )
--    [ WITH ( storage_parameter = value [, ... ] ) ]
--    [ TABLESPACE tablespace_name ]
--    [ WHERE predicate ]

CREATE INDEX test1 ON bar (b) WITH (FILLFACTOR=50);
CREATE INDEX CONCURRENTLY test2 ON baz  (d ASC) TABLESPACE event_db;
CREATE INDEX test3 ON bar (b) WHERE b BETWEEN '2013-01-01 00:00:00' and '2014-01-01 00:00:00';
--CREATE INDEX test4 ON baz USING gist(p);
--CREATE INDEX test5 ON bar2 (b) WITH (FILLFACTOR=50);


--
-- View Check
--

--CREATE [ OR REPLACE ] [ TEMP | TEMPORARY ] [ RECURSIVE ] VIEW name [ ( column_name [, ...] ) ]
--    [ WITH ( view_option_name [= view_option_value] [, ... ] ) ]
--    AS query
--    [ WITH [ CASCADED | LOCAL ] CHECK OPTION ]

CREATE EVENT TRIGGER before_create_view ON ddl_command_start WHEN TAG IN ('create view', 'create materialized view') EXECUTE PROCEDURE snitch();
CREATE EVENT TRIGGER after_create_view  ON ddl_command_end   WHEN TAG IN ('create view', 'create materialized view') EXECUTE PROCEDURE snitch();
CREATE EVENT TRIGGER drop_view          ON sql_drop          WHEN TAG IN ('drop view', 'drop materialized view')   EXECUTE PROCEDURE snitch();


CREATE VIEW barf (o) AS SELECT * from only_tz;
CREATE RECURSIVE VIEW barf_recursive (a) AS SELECT a from foo;
--CREATE VIEW rebarf (d) WITH (security_barrier=on) AS SELECT d from baz WITH CASCADED;
CREATE VIEW rebarf (a) WITH (security_barrier) AS SELECT a from foo  ;
CREATE VIEW rebarf_2 (a) AS SELECT a from foo WITH LOCAL CHECK OPTION;
CREATE VIEW barf_check AS SELECT * FROM nyan WITH CHECK OPTION;

--
-- Materialized View 
--

--CREATE MATERIALIZED VIEW table_name
--    [ (column_name [, ...] ) ]
--    [ WITH ( storage_parameter [= value] [, ... ] ) ]
--    [ TABLESPACE tablespace_name ]
--    AS query
--    [ WITH [ NO ] DATA ]

CREATE MATERIALIZED VIEW foo_mv AS SELECT * FROM bar WITH NO DATA;



-- 
-- Sequence Check
--


--CREATE [ TEMPORARY | TEMP ] SEQUENCE name [ INCREMENT [ BY ] increment ]
--    [ MINVALUE minvalue | NO MINVALUE ] [ MAXVALUE maxvalue | NO MAXVALUE ]
--    [ START [ WITH ] start ] [ CACHE cache ] [ [ NO ] CYCLE ]
--    [ OWNED BY { table_name.column_name | NONE } ]

-- CREATE TEMPORARY SEQUENCE isn't accepted on the tag list. 
-- Trigger should be fired on CREATE TEMP SEQUENCE using CREATE SEQUENCE tag
CREATE EVENT TRIGGER before_create_seq ON ddl_command_start WHEN TAG IN ('create sequence') EXECUTE PROCEDURE snitch();
CREATE EVENT TRIGGER after_create_seq  ON ddl_command_end   WHEN TAG IN ('create sequence') EXECUTE PROCEDURE snitch();
CREATE EVENT TRIGGER drop_seq          ON sql_drop          WHEN TAG IN ('drop sequence')   EXECUTE PROCEDURE snitch();




--CREATE SEQUENCE test_1_seq INCREMENT BY 1 MINVALUE 1 MAXVALUE 20 START WITH 1 CACHE 1 CYCLE OWNED BY NONE;
CREATE TEMPORARY SEQUENCE test_2_seq;
--CREATE TEMP SEQUENCE test_3_seq NO MINVALUE NO MAXVALUE NO CYCLE OWNED BY barf.o;

select nextval('test_2_seq');

-- 
-- Trigger Check
--



--
-- Drop objects
--

DROP EVENT TRIGGER before_create_seq;
DROP EVENT TRIGGER after_create_seq;
DROP EVENT TRIGGER drop_seq;

DROP EVENT TRIGGER IF EXISTS before_create_table;
DROP EVENT TRIGGER IF EXISTS after_create_table;
DROP EVENT TRIGGER IF EXISTS drop_table;
DROP EVENT TRIGGER before_create_view;
DROP EVENT TRIGGER after_create_view;
DROP EVENT TRIGGER drop_view;

DROP VIEW barf;
DROP VIEW barf_recursive;
DROP VIEW rebarf;
DROP VIEW rebarf_2;
DROP VIEW barf_check;
DROP MATERIALIZED VIEW foo_mv;
DROP TABLE foo CASCADE;
DROP TABLE baz CASCADE;
DROP TABLE bar2 CASCADE;
DROP TABLE bar CASCADE;
DROP TABLE nyan CASCADE;


DROP TABLESPACE event_db;








