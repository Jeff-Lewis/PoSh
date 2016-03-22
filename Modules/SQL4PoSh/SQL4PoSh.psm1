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