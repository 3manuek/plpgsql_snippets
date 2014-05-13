--
-- README 
--
-- The "tablespace" create feature and related statements are commented to avoid possible 
-- permission issues when creating the event_db folder.
-- Please uncomment and remove the tag of the lines starting with "--<UNCOMMENT>" to proceed
-- with the tablespace option enabled.



CREATE TABLE IF NOT EXISTS public.log (
  stamp timestamp,
  classid oid,
  objid oid,
  objsubid integer,
  objtype text,
  schema text,
  identity text,
  command json
);

CREATE OR REPLACE FUNCTION snitch() RETURNS event_trigger LANGUAGE plpgsql AS $$
DECLARE
        r RECORD;
BEGIN
        FOR r IN SELECT * FROM pg_event_trigger_get_creation_commands()
        LOOP
                INSERT INTO public.log VALUES (
					now(), r.classid, r.objid, r.objsubid, r.object_type,
					r.schema, r.identity, r.command
				);
                RAISE NOTICE 'expanded: %',
					pg_event_trigger_expand_command(r.command::json);
        END LOOP;
END;
$$;


-- Execute snitch on evey supported command:
CREATE EVENT TRIGGER snitch ON ddl_command_end
EXECUTE PROCEDURE snitch();

-- User created for certain commands
CREATE ROLE regression_event_user;

-- Dictionaries and configuration of FTS:
CREATE TEXT SEARCH DICTIONARY english_ispell (
    TEMPLATE = ispell,
    DictFile = ispell_sample,
    AffFile = ispell_sample,
    StopWords = english
);

CREATE TEXT SEARCH CONFIGURATION public.pg_conf_ts ( COPY = pg_catalog.english );

CREATE TEXT SEARCH DICTIONARY pg_dict (
    TEMPLATE = 'synonym', --originally was synonym http://www.postgresql.org/docs/8.3/static/textsearch-configuration.html, but isn't working
    SYNONYMS = pg_dict
);


-- Function section

CREATE OR REPLACE FUNCTION b1_1(xx int default 1)
      RETURNS SETOF INT
      LANGUAGE plpgsql
      ROWS 10
    AS 
$$
    DECLARE
       j int;
    BEGIN
      FOR j IN select i from generate_series(1,10) i(i)
      LOOP
        return next j;
      END LOOP;
    RETURN;
    END;
$$
;


CREATE OR REPLACE FUNCTION b2_1()
  RETURNS TABLE(col1 int, col2 text, col3 date) IMMUTABLE LANGUAGE plpgsql AS
$func$
BEGIN

RETURN QUERY EXECUTE
format ('SELECT 123, $$justsomedata$$::text, now()::date');
END
$func$;

CREATE OR REPLACE FUNCTION b1_2() RETURNS INT LANGUAGE SQL AS $B1_2$
SELECT round(random()*100)::int;
$B1_2$;

-- Inserts using functions:
CREATE TABLE b1(k int);
CREATE TABLE b2(col1 int, col2 text, col3 date);

INSERT INTO b1 SELECT b1_1();
INSERT INTO b1 SELECT b1_2();
INSERT INTO b2 SELECT * FROM b2_1();


--
-- CREATE COLLATE
--

CREATE COLLATION deparse_coll FROM "en_US";
CREATE COLLATION le_english (LC_COLLATE = "en_US", LC_CTYPE = "en_US");


--
-- CREATE AGGREGATE
--

CREATE AGGREGATE _avg_ (float8)
(
    sfunc = float8_accum,
    stype = float8[],
    finalfunc = float8_avg,
    initcond = '{0,0,0}'
);

CREATE AGGREGATE array_accum (anyelement)
(
    sfunc = array_append,
    stype = anyarray,
    initcond = '{}'
);



--
-- CREATE TYPE SECTION
--

CREATE TYPE small_int_list AS ENUM ('8','9','1');

CREATE TYPE range_test AS RANGE (SUBTYPE=int);



--<UNCOMMENT> \! mkdir -p /tmp/event_db
--<UNCOMMENT> \! chown postgres: /tmp/event_db
--<UNCOMMENT> CREATE TABLESPACE event_db LOCATION '/tmp/event_db';
--\! mkdir -p /tmp/test1
--\! mkdir -p /tmp/test2

--CREATE TABLESPACE test1 location '/tmp/test1';
--CREATE TABLESPACE test2 location '/tmp/test2';
--ALTER TABLESPACE test1 RENAME TO test1b;
--ALTER TABLESPACE test1b MOVE TABLES  TO test2;
--ALTER TABLESPACE test1b MOVE ALL  TO test2;
--DROP TABLESPACE test1b;
--DROP TABLESPACE test2;

-- CREATE SCHEMA
CREATE SCHEMA test_1;
CREATE SCHEMA test_2 AUTHORIZATION regression_event_user;
CREATE SCHEMA AUTHORIZATION regression_event_user;
CREATE SCHEMA IF NOT EXISTS test_3;

--
-- CREATE TABLE
--

CREATE TABLE test_1.foo (a int PRIMARY KEY, timing time) TABLESPACE pg_default;  --<UNCOMMENT> TABLESPACE event_db;

CREATE TABLE test_2.bar (b timestamptz(3), c "char", LIKE test_1.foo) WITH (autovacuum_enabled=off);

CREATE TABLE baz (d decimal(10, 4), e SERIAL, p point) INHERITS (test_2.bar);
CREATE TABLE nyan AS SELECT * FROM test_1.foo;

SET search_path TO 'test_1', 'test_2';
CREATE TABLE test_2.foo (hidden int);
CREATE TABLE bar2 (b timestamptz(3), LIKE foo INCLUDING ALL) INHERITS (foo, bar) WITH OIDS;

CREATE TABLE including_base (a INT PRIMARY KEY, b text CHECK (b <> 'hello'), c int REFERENCES test_1.foo);
CREATE TABLE only_like_1 (LIKE including_base);
CREATE TABLE only_like_2 (LIKE including_base INCLUDING CONSTRAINTS);
CREATE TABLE only_like_3 (LIKE including_base INCLUDING STORAGE);
CREATE TABLE only_like_4 (LIKE including_base INCLUDING INDEXES);
CREATE TABLE only_like_5 (LIKE including_base INCLUDING COMMENTS INCLUDING INDEXES INCLUDING STORAGE INCLUDING CONSTRAINTS);
CREATE TABLE only_like_6 (LIKE including_base INCLUDING ALL);

-- XXX what other INCLUDING clauses do we have?

CREATE TEMP TABLE temp_tb (i int);

CREATE SEQUENCE just_test_def;
CREATE TABLE test_table_3 ( id int PRIMARY KEY default nextval('just_test_def'));

-- resolve schemas correctly
CREATE SCHEMA r1 CREATE TABLE t (a int);
CREATE SCHEMA r2 CREATE TABLE t (b int);
CREATE SCHEMA r3 CREATE TABLE t (b int);
SET search_path TO 'r1', 'r2';
CREATE SCHEMA r4 CREATE TABLE t2 () INHERITS (r1.t);
CREATE SCHEMA r5 CREATE TABLE t2 () INHERITS (r2.t);
CREATE SCHEMA r6 CREATE TABLE t2 () INHERITS (r3.t);

SET search_path TO 'test_1', 'test_2', 'public';


-- Creates a table with all the types :
DO $$
DECLARE creat text;
BEGIN
	creat := 'create table testalltypes (';
	creat := creat || string_agg(format('col_%s %I', r, typname), ', ')
		FROM (
			SELECT row_number() OVER () AS r, typname
			FROM pg_type
			WHERE typtype = 'b' and typelem = 0) a;
	creat := creat || ')';
	EXECUTE creat;
END; $$;

-- Most usual types:
CREATE TABLE weirdtypes (
	a integer default 1,
	b int,
	c _int4,
	d int4[],
	d1 integer[],
	e integer[][],
	f timestamptz(6),
	g timestamp(2) with time zone,
	h timestamp(2) with time zone[],
	i _timestamptz(3),
	j time(4) with time zone,
	k timetz(3),
	l interval default '1 second'::interval,
	m interval year to month,
	n interval day to second,
	o interval second,
	p numeric(10,4),
	q decimal(100,25),
	r "char",
	s char,
	t char(1),
	u _char,
	u1 _bpchar,
	v char[],
	w varchar,
	x varchar(10),
	y float(1),
	z float(8),
	aa float(15),
	ab float(32),
	ac float(53),
	ad float(53)[1],
        ae tsvector CHECK (ae <> to_tsvector('The elephant is in the kitchen')),
        af int4,
        ag money,
        ah json[],
        ai json NOT NULL,
        aj jsonb,
        ak uuid,
        al point,
        am point[],
        an polygon
);



-- 
-- CREATE INDEX
--


CREATE UNIQUE INDEX test1 ON weirdtypes (af) WITH (FILLFACTOR=50);
CREATE INDEX CONCURRENTLY test2 ON baz  (d ASC) TABLESPACE pg_default; --<UNCOMMENT> TABLESPACE event_db;
CREATE INDEX test3 ON weirdtypes (af) WHERE g BETWEEN '2013-01-01 00:00:00' and '2014-01-01 00:00:00';
CREATE INDEX test4 ON baz USING gist(p);
CREATE INDEX test5 ON bar2 (b) WITH (FILLFACTOR=50);
CREATE INDEX test6 ON weirdtypes USING gin (ae);
CREATE INDEX test7 ON weirdtypes USING gist (ae);
CREATE INDEX test8 ON weirdtypes (s COLLATE "C" ASC NULLS FIRST);


--
-- CREATE VIEW
--
COMMIT;
SELECT '1';
CREATE VIEW barf (a) AS SELECT * from foo;
select 2;
CREATE RECURSIVE VIEW barf_recursive (a) AS SELECT a from foo;
select 3;
CREATE VIEW rebarf_baz (d)  AS (SELECT d from baz) WITH CASCADED CHECK  OPTION;
select 4;
CREATE VIEW rebarf_sb (d) WITH (security_barrier=0) AS SELECT d from baz;
select 5;
CREATE VIEW rebarf (a) WITH (security_barrier) AS SELECT a from foo  ;
select 6;
CREATE VIEW rebarf_2 (a) AS SELECT a from foo WITH LOCAL CHECK OPTION;
select 7;
CREATE VIEW barf_check AS SELECT * FROM nyan WITH CHECK OPTION;



--
-- CREATE MATERIALIZED VIEW 
--


CREATE MATERIALIZED VIEW foo_mv AS SELECT * FROM bar WITH NO DATA;
CREATE MATERIALIZED VIEW bar_mv (c) TABLESPACE pg_default AS SELECT c FROM bar WITH DATA;
CREATE MATERIALIZED VIEW nyan_mv WITH (fillfactor=50) AS SELECT * FROM nyan;


-- 
-- CREATE SEQUENCE
--



CREATE SEQUENCE test_1_seq INCREMENT BY 1 MINVALUE 1 MAXVALUE 20 START WITH 1 CACHE 1 CYCLE OWNED BY NONE;
CREATE TEMPORARY SEQUENCE test_2_seq;
CREATE TEMP SEQUENCE test_3_seq NO MINVALUE NO MAXVALUE NO CYCLE OWNED BY temp_tb.i;

-- 
-- CREATE TRIGGER
--


CREATE FUNCTION shoot() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END; $$;

CREATE TRIGGER generic_dummy BEFORE INSERT OR UPDATE OR DELETE  ON foo 
 FOR EACH ROW 
WHEN (1=1)
EXECUTE PROCEDURE shoot();

CREATE TRIGGER generic_ins_ INSTEAD OF INSERT  ON barf_check
FOR EACH ROW
EXECUTE PROCEDURE shoot();

CREATE TRIGGER generic_aft AFTER DELETE ON foo EXECUTE PROCEDURE shoot();

CREATE TRIGGER generic_st AFTER TRUNCATE ON bar FOR STATEMENT EXECUTE PROCEDURE shoot(); 

--
-- Following example is for the Constraint Trigger implementation:
--

CREATE TYPE elem_types AS ENUM ('elem1','elem2');

CREATE TABLE elements AS SELECT i, 'elem1'::elem_types as elem_type  from generate_series(1,10) i(i);

CREATE OR REPLACE FUNCTION duplicated_after_trigger() RETURNS TRIGGER AS $$
  BEGIN
    IF (SELECT count(i) 
           FROM elements 
        WHERE i=NEW.i 
          AND elem_type='elem1'::elem_types) > 1 THEN
      RAISE EXCEPTION 'Record duplicated';              
    END IF;
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;


CREATE CONSTRAINT TRIGGER constraint_trigger_example
AFTER INSERT OR UPDATE ON elements
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE PROCEDURE duplicated_after_trigger();

INSERT INTO elements VALUES (11,'elem2'::elem_types); -- should be fine
INSERT INTO elements VALUES (10,'elem2'::elem_types); -- should be fine too
INSERT INTO elements VALUES (9, 'elem1'::elem_types); -- Should FAIL by exception




--
-- CREATE RULE
--


CREATE OR REPLACE RULE rule_foo AS ON DELETE TO foo WHERE OLD.a > 10 DO INSTEAD NOTHING;
CREATE OR REPLACE RULE rule_foo2 AS ON INSERT TO bar DO ALSO INSERT INTO foo(a) (SELECT nextval('test_2_seq')::integer);
CREATE RULE  rule_sel AS ON SELECT TO foo DO INSTEAD SELECT 'dummy rule rule_sel' as a;
CREATE RULE  rule_upd AS ON UPDATE TO bar DO ALSO NOTHING;
--CREATE OR REPLACE RULE rule_foo2 AS ON INSERT TO bar DO INSTEAD INSERT INTO foo(a) (SELECT nextval('test_2_seq'));
-- XXX need to test rules with multiple actions

SELECT * FROM foo;


--
-- ALTER TABLE
--
CREATE TABLE tt();
ALTER TABLE tt ADD COLUMN a time(4) NOT NULL;
ALTER TABLE tt DROP COLUMN a;
ALTER TABLE tt ADD COLUMN a int, ALTER a SET NOT NULL;
ALTER TABLE tt ALTER COLUMN a DROP NOT NULL;

ALTER TABLE tt ADD COLUMN b text;
ALTER TABLE tt ALTER COLUMN b SET STORAGE EXTERNAL;

ALTER TABLE tt ADD CHECK (b IS NOT NULL) NOT VALID;
ALTER TABLE tt VALIDATE CONSTRAINT tt_b_check;
ALTER TABLE tt DROP CONSTRAINT tt_b_check;

ALTER TABLE tt ADD CONSTRAINT check_b_column CHECK (b IS DISTINCT FROM NULL);
ALTER TABLE tt ADD CONSTRAINT check_b_column_2 CHECK (b IS NOT DISTINCT FROM NULL);

ALTER TABLE tt SET tablespace pg_default;

ALTER TABLE tt alter a set not null;
create unique index tt_i on tt(a);
alter table tt replica identity using index tt_i;

-- 
-- DROPs 
--

-- DROP EVENT TRIGGER before_create_seq;
-- DROP EVENT TRIGGER after_create_seq;
-- DROP EVENT TRIGGER drop_seq;

-- DROP EVENT TRIGGER IF EXISTS before_create_table;
-- DROP EVENT TRIGGER IF EXISTS after_create_table;
-- DROP EVENT TRIGGER IF EXISTS drop_table;
-- DROP EVENT TRIGGER before_create_view;
-- DROP EVENT TRIGGER after_create_view;
-- DROP EVENT TRIGGER drop_view;

DROP VIEW barf;
DROP VIEW barf_recursive;
DROP VIEW rebarf;
DROP VIEW rebarf_2;
DROP VIEW barf_check;
DROP MATERIALIZED VIEW foo_mv;
DROP TABLE foo CASCADE;
DROP TABLE baz CASCADE;
DROP TABLE bar CASCADE;
DROP TABLE nyan CASCADE;

--<UNCOMMENT> DROP TABLESPACE event_db;



-- clean up
DROP EVENT TRIGGER snitch;


--
-- Special objects to test DROP statements
--

CREATE SCHEMA droptest
CREATE TABLE stuff (a serial PRIMARY KEY, the_object oid)
CREATE TABLE ref_stuff (b serial PRIMARY KEY, a_fk int NOT NULL REFERENCES stuff);

set search_path = droptest;
CREATE TYPE the_types AS ENUM('harder','better','faster','stronger');

CREATE FUNCTION return_the_types () RETURNS the_types LANGUAGE plpgsql AS
$$ DECLARE res the_types ; BEGIN SELECT (('{harder,better,faster,stronger}'::text[])[round(random()*3+1)])::the_types into res; RETURN res; END $$
;

INSERT INTO stuff(the_object) VALUES (lo_create(0));


DROP TABLE ref_stuff CASCADE;
DROP TYPE the_types CASCADE;
DROP SCHEMA droptest CASCADE;

