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

1. Define database connections in `omniquery_connection_settings.json`.
2. Write a SQL query where subqueries reference connection names using the `<connection_name>__<alias>` pattern.
3. OmniQuery processes each subquery, executes it against the appropriate database, and stores results in SQLite (all columns are stored as strings to prevent type mismatches).
4. The final query runs against the SQLite database.
5. Subqueries can reference values from another query using SQL comments like `/* <table_name>.<column_name> */`. These are always assumed to be quoted lists for now.
6. Results are exported to a CSV file and retained alongside the SQLite database for further inspection.

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

### Joining Data Across Sources Using SQL Notes

```sql
SELECT * FROM (
  SELECT id, created_by_id, record_value, record_type FROM records
) data1__records
LEFT JOIN (
  SELECT id, email, test_account FROM users WHERE id IN (/* records.created_by_id */)
) data2__users ON users.id = records.created_by_id
WHERE users.test_account = false;
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

This will generate a `omniquery.jar` file that can be executed with:

```sh
java -jar omniquery.jar <path to .sql>
```

## License

OmniQuery is free to use under the MIT License. This allows open usage while providing some protection for the author. See the `LICENSE` file for details.