#!/bin/bash
export SQLSERVER=localhost
export SQLDATABASE=test
export SQLUSERNAME=sa
export SQLPASSWORD='pa55word(!)Secret'
export MIGRATOR_DIR=$(pwd)/testdata

#####################################################################################
# SETUP

rm -rf testdata
mkdir testdata

cat > testdata/deletetables.ps1 <<EOF
\$server = \$env:SQLSERVER
\$database = \$env:SQLDATABASE
\$username = \$env:SQLUSERNAME
\$password = \$env:SQLPASSWORD
\$cs = "Data Source=\$server;Initial Catalog=\$database;User Id=\$username;Password=\$password;Integrated Security=false;"
\$sql = new-object System.Data.SqlClient.SqlConnection
\$sql.ConnectionString = \$cs
\$sql.Open()
\$cmd = \$sql.CreateCommand()
\$cmd.CommandText = "DROP TABLE dbmigrations;"
[void]\$cmd.ExecuteNonQuery()
\$cmd.Dispose()
\$cmd = \$sql.CreateCommand()
\$cmd.CommandText = "DROP TABLE test;"
[void]\$cmd.ExecuteNonQuery()
\$cmd.Dispose()
\$sql.Close()
\$sql.Dispose()
EOF


cat > testdata/testcount.ps1 <<EOF
\$server = \$env:SQLSERVER
\$database = \$env:SQLDATABASE
\$username = \$env:SQLUSERNAME
\$password = \$env:SQLPASSWORD
\$cs = "Data Source=\$server;Initial Catalog=\$database;User Id=\$username;Password=\$password;Integrated Security=false;"
\$sql = new-object System.Data.SqlClient.SqlConnection
\$sql.ConnectionString = \$cs
\$sql.Open()
\$cmd = \$sql.CreateCommand()
\$cmd.CommandText = "SELECT COUNT(*) c FROM test"
\$data = \$cmd.ExecuteScalar()
\$data
[void]\$cmd.Dispose()
[void]\$sql.Close()
[void]\$sql.Dispose()
EOF

cat > testdata/migratorcount.ps1 <<EOF
\$server = \$env:SQLSERVER
\$database = \$env:SQLDATABASE
\$username = \$env:SQLUSERNAME
\$password = \$env:SQLPASSWORD
\$cs = "Data Source=\$server;Initial Catalog=\$database;User Id=\$username;Password=\$password;Integrated Security=false;"
\$sql = new-object System.Data.SqlClient.SqlConnection
\$sql.ConnectionString = \$cs
\$sql.Open()
\$cmd = \$sql.CreateCommand()
\$cmd.CommandText = "SELECT COUNT(*) c FROM dbmigrations"
\$data = \$cmd.ExecuteScalar()
\$data
[void]\$cmd.Dispose()
[void]\$sql.Close()
[void]\$sql.Dispose()
EOF

pwsh testdata/deletetables.ps1

######################################################################################

cat << EOF > testdata/0001-create.sql
CREATE TABLE test (
  id bigint,
  name nvarchar(100)
);
EOF

echo "------------------ Running with create. ------------------------------------"
pwsh migrator.ps1

migratorcount=$(pwsh testdata/migratorcount.ps1)
testcount=$(pwsh testdata/testcount.ps1)

if [ $migratorcount != 1 ]; then
  echo "Migrator Count ($migratorcount) does not equal 1"
  exit 1
fi

if [ $testcount != 0 ]; then
  echo "Test Count ($testcount) does not equal 0"
  exit 1
fi

#####################################################################################

cat << EOF > testdata/0002-insert-multiple-lines.sql
INSERT INTO test (id, name) VALUES (1, 'test');
INSERT INTO test (id, name) VALUES (2, 'two');
EOF

echo "-------------------- Running with Multiple Queries. ------------------------------"
pwsh migrator.ps1

migratorcount=$(pwsh testdata/migratorcount.ps1)
testcount=$(pwsh testdata/testcount.ps1)

if [ $migratorcount != 2 ]; then
  echo "Migrator Count ($migratorcount) does not equal 2"
  exit 1
fi

if [ $testcount != 2 ]; then
  echo "Test Count ($testcount) does not equal 2"
  exit 1
fi

#####################################################################################

cat << EOF > testdata/0003-go.sql
INSERT INTO test (id, name) VALUES (3, 'three');
GO
INSERT INTO test (id, name) VALUES (4, 'four');
GO
EOF

echo "-------------------- Running with GO. ------------------------------------"
pwsh migrator.ps1

migratorcount=$(pwsh testdata/migratorcount.ps1)
testcount=$(pwsh testdata/testcount.ps1)

if [ $migratorcount != 3 ]; then
  echo "Migrator Count ($migratorcount) does not equal 3"
  exit 1
fi

if [ $testcount != 4 ]; then
  echo "Test Count ($testcount) does not equal 4"
  exit 1
fi

#####################################################################################

#TODO
export SQLENVIRONMENT=sa

cat << EOF > testdata/0004-location-subsitute.sql
INSERT INTO test (id, name) VALUES (1, 'abfss://curated@heauksdev1datalake01.dfs.core.windows.net');
EOF

echo "-------------------- Replace Location. -------------------------------"
pwsh migrator.ps1

migratorcount=$(pwsh testdata/migratorcount.ps1)
testcount=$(pwsh testdata/testcount.ps1)

if [ $migratorcount != 4 ]; then
  echo "Migrator Count ($migratorcount) does not equal 4"
  exit 1
fi

if [ $testcount != 5 ]; then
  echo "Test Count ($testcount) does not equal 5"
  exit 1
fi


#####################################################################################

cat << EOF > testdata/0005-good.sql
INSERT INTO test (id, name) VALUES (1, 'test');
EOF

cat << EOF > testdata/0006-broken.sql
INSERT INTO nowhere (id, name) VALUES (1, 'test');
EOF

echo "-------------------- Running with Broken file. -----------------------------------"
pwsh migrator.ps1

rm testdata/0006-broken.sql

migratorcount=$(pwsh testdata/migratorcount.ps1)
testcount=$(pwsh testdata/testcount.ps1)

if [ $migratorcount != 5 ]; then
  echo "Migrator Count ($migratorcount) does not equal 5"
  exit 1
fi

if [ $testcount != 6 ]; then
  echo "Test Count ($testcount) does not equal 6"
  exit 1
fi

#####################################################################################

cat << EOF > testdata/0001-new.sql
INSERT INTO test (id, name) VALUES (1, 'test');
EOF

echo "-------------------- Running with new 0001. -----------------------------------"
pwsh migrator.ps1

rm testdata/0001-new.sql

migratorcount=$(pwsh testdata/migratorcount.ps1)
testcount=$(pwsh testdata/testcount.ps1)

if [ $migratorcount != 5 ]; then
  echo "Migrator Count ($migratorcount) does not equal 5"
  exit 1
fi

if [ $testcount != 6 ]; then
  echo "Test Count ($testcount) does not equal 6"
  exit 1
fi

#####################################################################################

cat << EOF > testdata/0007-inlinego.sql
INSERT INTO test (id, name) VALUES (1, 'GOgo go GO test');
GO
EOF

echo "-------------------- Running with new inline go. -----------------------------------"
pwsh migrator.ps1

migratorcount=$(pwsh testdata/migratorcount.ps1)
testcount=$(pwsh testdata/testcount.ps1)

if [ $migratorcount != 6 ]; then
  echo "Migrator Count ($migratorcount) does not equal 6"
  exit 1
fi

if [ $testcount != 7 ]; then
  echo "Test Count ($testcount) does not equal 7"
  exit 1
fi

#####################################################################################

cat << EOF > testdata/0008-remove.sql
DROP TABLE test;
EOF

echo "------------------------  Clean up --------------------------------"
pwsh migrator.ps1

migratorcount=$(pwsh testdata/migratorcount.ps1)

if [ $migratorcount != 7 ]; then
  echo "Migrator Count ($migratorcount) does not equal 7"
  exit 1
fi

#####################################################################################
