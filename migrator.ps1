# A SQL Migrator - For running new pieces of SQL.
pwsh -Version

$FILE_LOCATION = $env:MIGRATOR_DIR
$REPLACEMENTS = @(@{find="LOCATION = '";replace="test"})

Write-Output "wWelcome To Migration"

Function Open-Sql-Connection{
  $server = $env:SQLSERVER
  $database = $env:SQLDATABASE
  $username = $env:SQLUSERNAME
  $password = $env:SQLPASSWORD
  $cs = "Data Source=$server;Initial Catalog=$database;Integrated Security=false;User Id=$username;Password=$password"
  $sql = new-object System.Data.SqlClient.SqlConnection
  $sql.ConnectionString = $cs
  $sql.Open()
  $sql
}

Function Close-Sql-Connection{
Param ($Sql)
 $Sql.Close()
 $Sql.Dispose()
}

Function Get-Or-Create-Migration-Table{
Param ($sql)
  try{
    $cmd = $sql.CreateCommand()
    $cmd.CommandText = "SELECT * FROM dbmigrations ORDER BY id DESC"
    $data = $cmd.ExecuteReader()
    $cmd.Dispose()
    try{
      $records = @()
      while ($data.Read())
      {
        $records += @{id=$data.GetValue(0); filename=$data.GetValue(1)}
      }
      $records
      $data.Close()
      Write-Host "Loading Migration Records."
    }
    catch {
      Write-Host "No Migrations Found."
      $data.Close()
    }
  }
  catch [System.Management.Automation.MethodInvocationException] {
    try {
      Write-Host "Creating Migration Table."
      $cmd.Dispose()
      $cmd = $sql.CreateCommand()
      $cmd.CommandText = "CREATE TABLE dbmigrations (id bigint, filename nvarchar(100), created_at datetime2)"
      [void]$cmd.ExecuteNonQuery()
      $cmd.Dispose()
    }
    catch [System.Management.Automation.MethodInvocationException] {
      echo "Failed to create dbmigrations table."
      throw $_.Exception
      exit 1
    }
  }
}

Function Get-Files{
Param ($Directory)
  $files = Get-ChildItem $Directory -Filter *.sql | Sort-Object
  Write-Output $files
  return
}

Function Filter-Missing-Files {
Param ($files, $dbmigrations)
 If (!$dbmigrations) {
   return $files
 }


 # These could possibly changed around with the max stuff below.
 foreach ($dbmigration in $dbmigrations){
   $files = $files | Where-Object -FilterScript {($_.Name -ne $dbmigration.filename)}
 }

 $maxId = $dbmigrations[0].id
 $files = $files | Where-Object -FilterScript {((Get-Id-From-Filename $_.Name) -gt $maxId)}

 $files
 return
}

# Split on GO and replace location
Function Modify-Migrations {
Param ($files)
  $splitoption = [System.StringSplitOptions]::RemoveEmptyEntries
  $fileandcontent = @()

  foreach ($f in $files){

    $filedata = Get-Content $f.FullName -Raw

    # This is currently not generalisable. Replaces location directly
    foreach ($replacement in $REPLACEMENTS) {
      $filedata = $filedata -replace $replacement.find,$replacement.replace
    }

    $splitongo = $filedata.replace("`n"," ").replace("`r"," ") -split "\s*GO\s*"

    For ($i=0; $i -lt $splitongo.Length; $i++) {
      if (![string]::IsNullOrEmpty($splitongo[$i])) {
        $fileandcontent += @{file=$f; content=$splitongo[$i]; part=$i} 
      }
    }
  }

  $fileandcontent
}

Function Execute-Migrations{
Param ($fileandcontent)
  $files = @()

  foreach ($f in $fileandcontent){
    $filedata = $f.content

    try {
      $cmd = $sql.CreateCommand()
      $cmd.CommandText = $filedata
      Write-Host $cmd.CommandText
      [void]$cmd.ExecuteNonQuery()
      $cmd.Dispose()
      # WARNING: This currently saves if a file is partially executed successfully.
      $files += $f.file
    }
    catch [System.Management.Automation.MethodInvocationException] {
      $name = $f.file.Name
      $part = $f.part
      Write-Host "ERROR: Issue with the file: $name part: $part"
      Write-Host $_.Exception
      break
    }
  }
  $files
}

Function Save-Completed-Migrations {
Param ($files)

  $files = $files | Sort-Object | Get-Unique

  foreach ($f in $files){
    $filename = $f.Name
    $id = Get-Id-From-Filename $f.Name

    $cmd = $sql.CreateCommand()
    $cmd.CommandText = "DECLARE @Date DATETIME; SET @Date = GETDATE(); INSERT INTO dbmigrations (id, filename, created_at) VALUES ($id, '$filename', @Date);"
    Write-Host $cmd.CommandText
    [void]$cmd.ExecuteNonQuery()
    $cmd.Dispose()
  }
}

Function Get-Id-From-Filename {
Param ($file)
  $regex = $file -match "^([0-9]+).*$"
  $match = [convert]::ToInt32($matches[1], 10)
  Write-Output $match
}


# Main
$sql = Open-Sql-Connection

$migrationdata = Get-Or-Create-Migration-Table $sql

$allfiles = Get-Files $FILE_LOCATION

$files = Filter-Missing-Files $allfiles $migrationdata

#Output
Write-Output "Changed Files:" $files

$fileandcontents = Modify-Migrations $files

$executedfiles = Execute-Migrations $fileandcontents

Save-Completed-Migrations $executedfiles

Close-Sql-Connection $sql
