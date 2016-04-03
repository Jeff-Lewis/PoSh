# TODO
#  поиграться  с ParameterSetName для кореетного ввода
function Get-ConnectionString {
    [CmdletBinding()]
    param (
        [parameter(
            Mandatory = $true,
            HelpMessage = 'Enter server name.'
        )]
        [string]$server,

        [parameter(
            HelpMessage = 'If use not default instance, enter name.'
        )]
        [string]$instance,

        [parameter(
            Mandatory = $true,
            HelpMessage = 'Enter database name.'
            )]
        [string]$database,

        [parameter(
            ParameterSetName = 'NativeUser',
            HelpMessage = 'Enter user name.'
        )]
        [string]$user,

        [parameter(
            ParameterSetName = 'NativeUser',
            HelpMessage = 'Enter password.'
        )]
        [string]$password,

        [parameter(
            ParameterSetName = 'NTLMUser',
            HelpMessage = 'If you use trusted connection method, use this switch. User/password option not use.'
        )]
        [Alias('trustedUser')]
        [switch]$trustedConnection,

        [parameter(
            HelpMessage = 'if connect with OLE DB, use this option'
        )]
        [ValidateSet('Access', 'Active Directory', 'MySQL', 'Oracle', 'Microsoft')]
        
        [string]$oledb,
        
        [parameter()]
        [string]$datasource,

        [parameter()]
        [hashtable]$custom
    )
    begin {
        $string = @{};
    }
    process {
        if (![String]::IsNullOrEmpty($oledb)) {
            switch ($oledb) {
                'Oracle' {
                    $string.'Provider' = 'OraOLEDB.Oracle';
                    $string.'Date Source' = $datasource;
                    if ($trustedConnection.IsPresent) {
                        $string.'OSAuthent' = '1';
                    }
                    else {
                        $string.'User Id'= $user;
                        $string.'Password' = $password;
                    }
                }
                'Access' {
                    $string.'Provider' = 'Microsoft.ACE.OLEDB.12.0';
                    $string.'Data Source' = $datasource;
                    if ($trustedConnection.IsPresent) {
                        $string.'Persist Security Info' = 'False';
                    }
                    else {
                        $string.'Jet OLEDB:Database Password' = $password;
                    }
                }
                'Active Directory' {
                    $string.'Provider' = 'ADSDSOObject';
                    if (!$trustedConnection.IsPresent) {
                        $string.'User Id' = $user;
                        $string.'Password' = $password;
                    }
                }
                'Microsoft' {
                    $string.'Provider' = 'sqloledb';
                    $string.'Data Source' = $datasource;
                    if (![System.String]::IsNullOrEmpty()) {
                        $string.'Data Source'    
                    }
                    $string.'Initial Catalog' = $database;
                    if($trustedConnection.IsPresent) {
                        $string.'Integrated Security' = 'SSPI';
                    }
                    else {
                        $string.'User Id' = $user;
                        $string.'Password' = $password;
                    }
                }
                'MySQL' {
                    $string.'Provider' = 'MySQLProv';
                    $string.'Data Source' = $datasource;
                    $string.'Uid' = $user;
                    $string.'Pwd' = $password;
                }
            } 
        }
        else {
            $string.'Server' = $server;
            if (![String]::IsNullOrEmpty($instance)) {
                $string.'Server' += "\$instance";
            }
            $string.'Database' = $database;
            if ($trustedConnection.IsPresent) {
                $string.'Trusted_Connection' = 'True';
            }
            else {
                $string.'User Id' = $user;
                $string.'Password' = $password;
            }
        }

        if ($custom.Count -ne 0) {
            $string += $custom;
        }

        return [string]::Join(" ", ($string.GetEnumerator() | ForEach-Object -Process { "$($_.Key)=$($_.Value);" }));
    }
}

function Get-SQLData {
    [CmdletBinding()]
    param (
        [string]$connsetcionString,
        [string]$query,
        [switch]$isSQLServer
    )
    begin {
        #[System.Data.Common.DbConnection]$connection = $null;
        if ($isSQLServer.IsPresent) {
            # Adding event handers for info messages
            $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection;
            $sqlInfoMessageHandler = {
                $EventsArgs;
            }
            $sqlInfomessageEvent = Register-ObjectEvent -InputObject $connection -EventName 'InfoMessage' -Action $sqlInfoMessageHandler;    
        }
        else {
            $connection = New-Object -TypeName System.Data.OleDb.OleDbConnection;
        }    
        
        $connection.ConnectionString = $connsetcionString;
        $connection.Open();
    }

    process {
        [System.Data.Common.DbCommand]$command = $connection.CreateCommand();
        
        $command.CommandText = $query;
        
        [System.Data.Common.DataAdapter]$adapter = $null;
        if ($isSQLServer.IsPresent) {
            $adapter = New-Object -TypeName System.Data.SqlClient.SqlDataAdapter($command);
        }
        else {
            $adapter = New-Object -TypeName System.Data.OleDb.OleDbDataAdapter($command);
        }

        [System.Data.DataSet]$dataSet = New-Object -TypeName System.Data.DataSet;
        $result = @{};
        try {
            $adapter.Fill($dataSet);
            $result.data = $dataSet.Tables[0];
        }
        catch {
            $result.'Errors' = $_.Exception.InnerException.Errors;
        }

        return $result;
    }

    end {
        if (($connection.State -ne 'Closed') -or ($connection.State -ne 'Broken')) {
            $connection.Close();            
        }
        Unregister-Event -SourceIdentifier $sqlInfomessageEvent.Name;
    }
}

<#
.SYNOPSIS
Executes a SQL statement against the connection and returns the number of rows affected.

.DESCRIPTION
Executes a SQL statement against the connection and returns the number of rows affected. 
Also return errors and info message.

.PARAMETER connectionString
String used to open a SQL Server database. You can use cmdlet Get-ConnectionString to 
get format string or do it yorself (http://connectionstrings.com).

.PARAMETER query
String with sql instructions

.PRAMETER isSQLServer
Switching to use of SQL Server

.PARAMETER withTransact
Switching to the use of the transaction mechanism. One transaction is used for all requests 
sent via pipeline. if you want to use transactions for each request individually, it is 
necessary to use cmdlet's foreach.

.INPUTS
String. You can pipe query string objects.

.OUTPUTS
Hashtable. Returns the number of rows for the query, as well as related information, and 
error messages.

.EXAMPLE
$query = "print 'Hello, World!'";
Invoke-SQLQuery -connectionString $str -query $query;

.EXAMPLE
$query = @("print 123", "print 'Hello, World!'");
$query | Invoke-SQLQuery -connectionString $str -isSQLServer;

#>
function Invoke-SQLQuery {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Enetr connection string'
        )]
        [string]$connectionString,

        [parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            HelpMessage = 'Enter query string'
        )]
        [AllowEmptyString()]
        [string]$query,

        [parameter(
            HelpMessage = 'Use to connect SQl Server'
        )]
        [switch]$isSQLServer,

        [parameter(
            HelpMessage = 'Use to enable transaction mechanism'
        )]
        [switch]$withTransact
    )
    begin {
        # Create connection
        if($isSQLServer.IsPresent) {
            [System.Data.Common.DbConnection]$connection = New-Object -TypeName System.Data.SqlClient.SqlConnection;
            # Continue processing the rest of the statements in a command regardless of any errors produced by the server
            $connection.FireInfoMessageEventOnUserErrors = $true;
        }
        else {
            [System.Data.Common.DbConnection]$connection = New-Object -TypeName System.Data.OleDb.OleDbConnection;
        }
        
        # Open connection
        $connection.ConnectionString = $connectionString;
        $connection.Open();

        # Use transaction
        if ($withTransact.IsPresent) {
            [System.Data.Common.DbTransaction]$transaction = $connection.BeginTransaction();
        }
    }
    process {
        # Zero out result for each pipe query.
        [hashtable]$result = @{};
        
        [System.Data.Common.DbCommand]$command = $connection.CreateCommand();
        $command.CommandText = $query;

        # Use transaction
        if ($withTransact.IsPresent) {
            $command.Transaction = $transaction;
        }
        
        # Adding event handers for info messages
        [scriptblock]$scriptInfoMessage =  {
            # Add to $result.errors
            $event.MessageData.errors += $eventArgs.Errors;
        }
        # Create hide event. Only this method is work!!! 
        Register-ObjectEvent -InputObject $connection -EventName 'InfoMessage' -Action $scriptInfoMessage -MessageData $result -SupportEvent;
        
        # Execute
        $result.rowCount = $command.ExecuteNonQuery();
        
        return $result;
    }
    end {
        # Use transaction
        if ($withTransact.IsPresent) {
            try {
                $transaction.Commit();
            }
            catch {
                try {
                    $transaction.Rollback();
                }
                catch {
                }
            }
        }
        
        # Close Connection
        $connection.Close();
    }
}

function Invoke-SQLReader {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Enetr connection string'
        )]
        [string]$connectionString,

        [parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true,
            HelpMessage = 'Enter query string'
        )]
        [AllowEmptyString()]
        [string]$query,

         [parameter(
            HelpMessage = 'Use to connect SQl Server'
        )]
        [switch]$isSQLServer
    )

    begin {
        # Create connection
        if($isSQLServer.IsPresent) {
            [System.Data.Common.DbConnection]$connection = New-Object -TypeName System.Data.SqlClient.SqlConnection;
            # Continue processing the rest of the statements in a command regardless of any errors produced by the server
            $connection.FireInfoMessageEventOnUserErrors = $true;
        }
        else {
            [System.Data.Common.DbConnection]$connection = New-Object -TypeName System.Data.OleDb.OleDbConnection;
        }

        # Open connection
        $connection.ConnectionString = $connectionString;
        $connection.Open();
    }

    process {
        # Zero out result for each pipe query.
        [hashtable]$result = @{};

        # Adding event handers for info messages
        [scriptblock]$scriptInfoMessage =  {
            # Add to $result.errors
            $event.MessageData.errors += $eventArgs.Errors;
        }
        # Create hide event. Only this method is work!!! 
        Register-ObjectEvent -InputObject $connection -EventName 'InfoMessage' -Action $scriptInfoMessage -MessageData $result -SupportEvent;
        
        [System.Data.Common.DbCommand]$command = $connection.CreateCommand();
        $command.CommandText = $query;
        [System.Data.Common.DbDataReader]$reader = $command.ExecuteReader();
        [System.Data.DataTable]$result.data = New-Object -TypeName System.Data.DataTable;
        $result.data.Load($reader);
        $reader.Close();
        return $result;
    }
    end {
        $connection.Close();
    }
}