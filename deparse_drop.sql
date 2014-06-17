-- 
-- Drop all the tables and elements created by deparse_util.sql script
--

            List of relations
 Schema |   Name    |   Type   |  Owner   
--------+-----------+----------+----------
 public | b1        | table    | postgres
 public | b2        | table    | postgres
 public | baz       | table    | postgres
 public | baz_e_seq | sequence | postgres
 public | log       | table    | postgres
 public | nyan      | table    | postgres
(6 rows)

test=# \d test_1
Did not find any relation named "test_1".
test=# set search_path = test_1;
SET
test=# \d       
                   List of relations
 Schema |      Name      |       Type        |  Owner   
--------+----------------+-------------------+----------
 test_1 | bar2           | table             | postgres
 test_1 | bar_mv         | materialized view | postgres
 test_1 | barf           | view              | postgres
 test_1 | barf_check     | view              | postgres
 test_1 | barf_recursive | view              | postgres
 test_1 | elements       | table             | postgres
 test_1 | foo            | table             | postgres
 test_1 | foo_mv         | materialized view | postgres
 test_1 | including_base | table             | postgres
 test_1 | just_test_def  | sequence          | postgres
 test_1 | nyan_mv        | materialized view | postgres
 test_1 | only_like_1    | table             | postgres
 test_1 | only_like_2    | table             | postgres
 test_1 | only_like_3    | table             | postgres
 test_1 | only_like_4    | table             | postgres
 test_1 | only_like_5    | table             | postgres
 test_1 | only_like_6    | table             | postgres
 test_1 | qq             | table             | postgres
 test_1 | rebarf         | view              | postgres
 test_1 | rebarf_2       | view              | postgres
 test_1 | rebarf_baz     | view              | postgres
 test_1 | rebarf_sb      | view              | postgres
 test_1 | test_1_seq     | sequence          | postgres
 test_1 | test_table_3   | table             | postgres
 test_1 | testalltypes   | table             | postgres
 test_1 | tt             | table             | postgres
 test_1 | weirdtypes     | table             | postgres
(27 rows)

test=# set search_path = test_2;
SET
test=# \d 
        List of relations
 Schema | Name | Type  |  Owner   
--------+------+-------+----------
 test_2 | bar  | table | postgres
 test_2 | foo  | view  | postgres
(2 rows)

test=# ?\dT
          List of data types
 Schema |      Name      | Description 
--------+----------------+-------------
 public | range_test     | 
 public | small_int_list | 
(2 rows)


