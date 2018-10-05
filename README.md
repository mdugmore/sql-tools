# sql-tools
Collection of SQL queries for various solutions I have needed

# Drop all Foreign Keys, Truncate Tables and Recreate Foreign Keys

The DropForeignKeysTruncateAndCreateFK.sql allows you to specify a list of tables to truncate and then drop all Foreign Keys in database and then truncate the tables and then finally recreate the Foreign Keys.

This is used when needing to Truncate tables but if there are Foreign Keys on referencing the tables a Truncate will not be allowed.
