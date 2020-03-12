# Powershell SQL Migrator

This performs SQL migrations using powershell. This for use with an Azure Datalake.

Warning: If a migration partially succeeds it is added to the migrations db.

# Running

Set the replacements to be correct at the top of the `migrator.ps1` (L2).

Run the `migrator.ps1` to run the program.

# Other scripts

* `test.sh` - Runs the tests for this project. (Need to create a local db).
* `export.sh` - Use `$ source export.sh` to set up your local environment.
* `createdb.sh` - Contains instructions for setting up a local SQL Server for the tests.
