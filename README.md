# OmniQuery
OmniQuery: Effortless cross-database queries using native SQL and JDBC—unify your data without the hassle.

OmniQuery is a lightweight Ruby-based tool that allows you to query across multiple databases using JDBC connections. Unlike Apache Drill, which requires an understanding of the entire SQL structure, OmniQuery lets you use each data source's native SQL dialect. This means you can perform operations like extracting values from JSONB in PostgreSQL and joining them with results from MySQL seamlessly.

## Features

- Supports multiple JDBC connection types.
- Allows writing queries using each source's native SQL syntax.
- Uses a JSON configuration file to define database connections.
- Enables cross-database joins by aliasing subqueries.
- Allows subqueries to reference values from other queries using SQL comments.
- Stores intermediate results in a local SQLite database to ensure consistency.
- Exports query results to CSV for easy analysis.

## Supported Databases

Currently, OmniQuery supports the following JDBC sources:

- MySQL
- PostgreSQL
- SQLite3
- MSSQL
- MariaDB

## How It Works

* Define database connections in `omniquery_connection_settings.json`.
* Write a SQL query where subqueries reference connection names using the `<connection_name>__<alias>` pattern.
* OmniQuery processes each subquery, executes it against the appropriate database, and stores results in SQLite (all columns are stored as strings to prevent type mismatches).
* The final query runs against the SQLite database.
* Subqueries can reference result values from another query using SQL comments like `/* [unquoted|nonunique|nullable] <table_name>.<column_name> */`.
* The default substitution for a result reference is a unique quoted list (e.g. "'foo','bar'")
  * **unquoted**: Removes the single quotes surrounding the values
  * **nonunique**: Sends all values, even if they are duplicated
  * **nullable**: Returns 'null' in the case of no values, versus the default of "''"
* The table name reference can simply be '*' which means it will attempt to merge the results of all other subqueries
* By default results are exported to a CSV file and retained in the SQLite database for further inspection.

## Connection Settings

Database connections are defined in a JSON file, `omniquery_connection_settings.json`:

```json
{
  "data1": {
    "connection": "jdbc:mysql://127.0.0.1:6667/database1",
    "user": "alice",
    "password": "securepass1"
  },
  "data2": {
    "connection": "jdbc:postgresql://127.0.0.1:5432/database2",
    "user": "bob",
    "password": "securepass2"
  }
}
```

## Query Examples

### Simple Union Query Across Two Databases

```sql
SELECT * FROM (
  SELECT 'car' AS record_type, id, name FROM cars LIMIT 25
) data1__cars
UNION ALL
SELECT * FROM (
  SELECT 'pet' AS record_type, id, name FROM pets LIMIT 25
) data2__pets;
```

### Joining Data Across Sources While Referencing Results

```sql
SELECT * FROM (
  SELECT id, created_by_id, record_value, record_type FROM records
) data1__records
LEFT JOIN (
  SELECT id, email, test_account FROM users WHERE id IN (/* records.created_by_id */)
) data2__users ON users.id = records.created_by_id
WHERE users.test_account = false;
```

### Reference Results From Multiple Sources

```sql
SELECT * FROM (
  SELECT * FROM (
    SELECT 'cars' as record_type, c.created_by_id, count(distinct c.id) as record_count
    FROM cars c
    WHERE p.created_at > '2025-03-15'
    GROUP BY 1,2
  ) data1__cars
  union all
  SELECT * FROM (
    SELECT 'cats' as record_type, c.created_by_id, count(distinct c.id) as record_count
    FROM cats c
    WHERE c.created_at > '2025-03-15'
    GROUP BY 1,2
  ) data2__cats
) r
left join (
  SELECT u.id, u.email, u.first_name FROM users u
  WHERE u.id in (/* *.created_by_id */)
) data3__users u on u.id = r.created_by_id
```

## Command Line Options
```text
-s, --connection_settings = path to the connection settings json file; omniquery_connection_settings.json will be used if not specified
-f, --sql_file = path to the sql file to execute. required.
-c, --csv = path to the csv file to create; will auto create if not specified
-l, --sqlite = path to the sqlite file to create; will auto create if not specified
-o, --final_sql = path to create the resulting sqlite query
-db, --dbeaver = path to dbeaver if using to open resulting sqlite file
-dbf, --dbeaver_folder = optional connections folder to add the new connection to
--nocsv = Option to prevent making a csv altogether
--pry = open pry to debug manually
--version = print the version
```

## Installation & Usage

### Running the Script

To execute a query using OmniQuery, run:

```sh
ruby bin/omniquery.rb <path to .sql>
```

### Compiling to a JAR

To compile OmniQuery into a JAR file using Warbler, run:

```sh
gem install warbler
warble executable jar
```

This will generate a `omniquery.jar` file (or you can download a pre-compiled .jar) that can be executed with:

```sh
java -jar omniquery.jar <path to .sql>
```

## Next Enhancements

1. CLI to specify connection settings, optional output, verbose logging or not, including the final SQL
2. Integration with VSCode or DBeaver; I want a quick way to build queries, execute them, and get at the results

## License

OmniQuery is free to use under the MIT License. This allows open usage while providing some protection for the author. See the `LICENSE` file for details.