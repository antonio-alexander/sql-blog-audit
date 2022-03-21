# sql-blog-audit

The purpose of this repo is to demonstrate how to implement audit tables within a database. Audit tables are a common need/desire for long-term database support/maintenance and scalability. Auditing allows you to answer some basic questions about each row/entity of data that otherwise might be difficult/impossible. It can also give you the ability to view changes and "undo" them or at least capture those changes such that they could be undone while maintaining any changes made after that. Auditing tables are best populated via triggers after updates/inserts into the table being audited. Although not necessary, the audit table should keep track of versions and create a "copy" of the source data with the assumption that the version will be updated for each atomic mutation of a given row.

These links may help:

- [https://www.mysqltutorial.org/mysql-stored-procedure-tutorial.aspx](https://www.mysqltutorial.org/mysql-stored-procedure-tutorial.aspx)
- [https://dev.mysql.com/doc/refman/5.7/en/trigger-syntax.html](https://dev.mysql.com/doc/refman/5.7/en/trigger-syntax.html)
- [https://mariadb.com/kb/en/delimiters/](https://mariadb.com/kb/en/delimiters/)
- [https://thispointer.com/error-code-1364-solved-field-doesnt-have-a-default-value/](https://thispointer.com/error-code-1364-solved-field-doesnt-have-a-default-value/)

## Loading the sql statements

Unfortunately the sql file contains trigggrs and setting/unsetting of the delimeter, so it fails if you attempt to load it in the docker-entrypoint-initdb.d. In this case, you can copy+pasta the sql file AFTER you login to the docker container:

```sh
docker compose up -d
docker exec -it mysql mysql -u root -p
```

## Audit table

The audit tables are identical for practical purposes and the collection of triggers seeks to simplify, automate and to a degree prevent things that could make auditing inconsistent. In short, the collection of triggers and tables ensure that EVERY time a row on the base table (employee and team) is mutated, a "copy" of that data is inserted into the audit table. Audit tables as implemented, will answer the following questions:

- When did this edit on a specific row occur?
- What order did these specific edits occur?
- Who did this specific edit?
- What was changed in this specific edit?

To show the audit tables/triggers in action, lets insert/update an employee:

```mysql
MariaDB [(none)]> use sql_blog_audit;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
MariaDB [sql_blog_audit]> insert into employee(first_name, last_name, email_address) values('Antonio','Alexander','antonio-alexander@mistersoftwaredeveloper.com');
Query OK, 1 row affected (0.002 sec)

MariaDB [sql_blog_audit]> select * from employee;
+----+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
| id | first_name | last_name | email_address                                 | version | last_updated        | last_updated_by |
+----+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
|  2 | Antonio    | Alexander | antonio-alexander@mistersoftwaredeveloper.com |       1 | 2022-03-20 17:25:05 | root@localhost  |
+----+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
1 row in set (0.001 sec)

MariaDB [sql_blog_audit]> select * from employee_audit;
+-------------+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
| employee_id | first_name | last_name | email_address                                 | version | last_updated        | last_updated_by |
+-------------+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
|           2 | Antonio    | Alexander | antonio-alexander@mistersoftwaredeveloper.com |       1 | 2022-03-20 17:25:05 | root@localhost  |
+-------------+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
1 row in set (0.001 sec)

MariaDB [sql_blog_audit]> select * from employee_uuid;
+--------------------------------------+-------------+
| employee_uuid                        | employee_id |
+--------------------------------------+-------------+
| 61f822a2-a821-11ec-b59a-0242ac180002 |           2 |
+--------------------------------------+-------------+
1 row in set (0.000 sec)

MariaDB [sql_blog_audit]> update employee set first_name='Tony' where first_name='Antonio';
Query OK, 1 row affected (0.008 sec)
Rows matched: 1  Changed: 1  Warnings: 0

MariaDB [sql_blog_audit]> select * from employee;
+----+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
| id | first_name | last_name | email_address                                 | version | last_updated        | last_updated_by |
+----+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
|  2 | Tony       | Alexander | antonio-alexander@mistersoftwaredeveloper.com |       2 | 2022-03-20 17:25:54 | root@localhost  |
+----+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
1 row in set (0.001 sec)

MariaDB [sql_blog_audit]> select * from employee_audit;
+-------------+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
| employee_id | first_name | last_name | email_address                                 | version | last_updated        | last_updated_by |
+-------------+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
|           2 | Antonio    | Alexander | antonio-alexander@mistersoftwaredeveloper.com |       1 | 2022-03-20 17:25:05 | root@localhost  |
|           2 | Tony       | Alexander | antonio-alexander@mistersoftwaredeveloper.com |       2 | 2022-03-20 17:25:54 | root@localhost  |
+-------------+------------+-----------+-----------------------------------------------+---------+---------------------+-----------------+
2 rows in set (0.000 sec)

MariaDB [sql_blog_audit]> 
```

From the logs, you should see the following:

1. Insert an employee
2. Verify that employee inserted
3. Verify that employee_audit table shows mutation
4. Update an employee
5. Verify that employee updated
6. Verify that the employee audit tables shows the mutation

One of the ways that we ensure the audit table is logically consistent is by having a version that atomically increments each time a row is mutated (even by different users). As a result, the audit table should have a row each time a row is changed. This is accomplished using a variety of tools, but lets start with the employee table first:

```sql
CREATE TABLE IF NOT EXISTS employee (
    -- KIM: this has to be NOT NULL in order to prevent the audit info trigger
    --  from failing 
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    first_name TEXT DEFAULT '',
    last_name TEXT DEFAULT '',
    email_address TEXT NOT NULL,
    version INT NOT NULL DEFAULT 1,
    last_updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_updated_by TEXT NOT NULL DEFAULT CURRENT_USER,
    UNIQUE(email_address)
) ENGINE = InnoDB;
```

The employee table has three fields to facilitate auditing:

- version: an integer that is atomically incremented each time a row is mutated
- last_updated: the database time where the mutation occurred
- last_updated_by: the database user that performed the mutation

Whenever a mutation occurs, the employee_audit table is updated, it has the following schema:

```sql
CREATE TABLE IF NOT EXISTS employee_audit (
    employee_id BIGINT,
    first_name TEXT,
    last_name TEXT,
    email_address TEXT,
    version INT NOT NULL,
    last_updated DATETIME NOT NULL,
    last_updated_by TEXT NOT NULL,
    FOREIGN KEY (employee_id) REFERENCES employee(id) ON DELETE CASCADE,
    PRIMARY KEY (employee_id, version)
) ENGINE = InnoDB;
```

Note that although this table shares the same values as the employee table, it's unique in that it:

- Only has one foreign key constraint (on employee id)
- Only enforced NOT NULL for audit fields (version, last_updated, last_updated_by)
- Has a primary key of employee_id and version

Those changes ensure that if an employee is deleted, it's audit table entries are ALSO deleted (maintaining data consistency) as well as ensuring that the audit table remains consistent in that there should only be a single entry per employee per version. Now you may be asking yourself, how can we ensure that the audit values are always sane, we do that through a trigger that runs AFTER INSERT and BEFORE UPDATE on the employee table:

```sql
DELIMITER //
CREATE TRIGGER employee_audit_info_insert
BEFORE INSERT
    ON employee FOR EACH ROW
BEGIN
    SET new.version = 1, new.last_updated = CURRENT_TIMESTAMP, new.last_updated_by = CURRENT_USER;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER employee_audit_info_update
BEFORE UPDATE
    ON employee FOR EACH ROW
BEGIN
    SET new.version = old.version+1, new.last_updated = CURRENT_TIMESTAMP, new.last_updated_by = CURRENT_USER;
END//
DELIMITER ;
```

These triggers effectively override any values set to ensure that they're sane and not spoofed. If version was incorrect for some reason, the trigger could fail forcing a rollback of the original transaction (e.g. the current mutex is 5 and it's set to 5 or 4) and we prevent situations where users could "try" to masquerade as someone else. There's also the option of having a separate table altogether that has the "live" audit information, but I think this is more practical.

We also use a trigger to automate insertions to the audit tables:

```sql
DELIMITER //
CREATE TRIGGER employee_audit_insert
AFTER INSERT
    ON employee FOR EACH ROW BEGIN
INSERT INTO
    employee_audit(employee_id, first_name, last_name, email_address, version, last_updated, last_updated_by)
values
    (new.id, new.first_name,  new.last_name, new.email_address, new.version, new.last_updated, new.last_updated_by);
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER employee_audit_update
AFTER UPDATE
    ON employee FOR EACH ROW BEGIN
INSERT INTO
    employee_audit(employee_id, first_name, last_name, email_address, version, last_updated, last_updated_by)
values
    (new.id, new.first_name,  new.last_name, new.email_address, new.version, new.last_updated, new.last_updated_by);
END//
DELIMITER ;
```

Each time a mutation happens to the employee table, an insert is made to the audit table capturing each mutation.

## Auditing vs history

This is an aside, but in practice you may get an itch to use the audit tables for something other than auditing, like history. Lets say that you want to know what groups employees have been a member of, you could take an easy route and do the following:

- create a team table that defines the team
- update the employee table to reference the team with a foreign key constraint for team id on the teams table

With the above, you could then answer the question, "What teams has this employee been a member of", by querying the audit table and looking for unique values for teams. But history isn't quite auditing is it; what if, someone fat fingered a button and they were accidentally added to the wrong team and we know this for a fact. To reflect that in an audit table, we'd need to edit the audit table such that the mutation referencing the change to that team is no longer present: __we'd have to ruin the consistency of our audit tables__.

Be careful about using audit tables for anything other than auditing, audit tables should be considered read-only except for when you delete data you no longer care about auditing i.e., delete all audit data before data x.
