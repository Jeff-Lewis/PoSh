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
        [ValidateSet('Access', 'Active Directory', 'MySQL', 'Oracle')]
        
        [string]$oledb,
        [parameter()]
        [string]$datasource


    )
    process {
        [string]$string = $null;
        if (![String]::IsNullOrEmpty($oledb)) {
            switch ($oledb) {
                'Oracle' {
                    $string += "Provider=OraOLEDB.Oracle; Date Source=$datasource; ";
                    if ($trustedConnection.IsPresent) {
                        $string += 'OSAuthent=1; ';
                    }
                    else {
                        $string += "User Id=$user; Password=$password; ";
                    }
                }
                'Access' {
                    $string += "Provider=Microsoft.ACE.OLEDB.12.0; Data Source=$datasource; ";
                    if ($trustedConnection.IsPresent) {
                        $string += "Persist Security Info=False; ";
                    }
                    else {
                        $string += "Jet OLEDB:Database Password=$password; ";
                    }
                }
                'Active Directory' {
                    $string += 'Provider=ADSDSOObject; ';
                    if (!$trustedConnection.IsPresent) {
                        $string += "User Id=$user;Password=$password; "
                    }
                }
                'MySQL' {
                    $string += "Provider=MySQLProv; Data Source=$datasource; ";
                    $string += "Uid=$user; Pwd=$password; ";
                }

            } 
        }
        else {
            $string += "Server=$server";
            if (![String]::IsNullOrEmpty($instance)) {
                $string += "\$instance";
            }
            $string += "; Database=$database; "
            if ($trustedConnection.IsPresent) {
                $string += "Trusted_Connection=True;"   
            }
            else {
                $string += "User Id=$user; Password=$password;"
            }
        }

        return $string;
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
        [System.Data.Common.DbConnection]$connection = $null;
        if ($isSQLServer.IsPresent) {
            $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection;
        }
        else {
            $connection = New-Object -TypeName System.Data.OleDb.OleDbConnection;
        }
        
        $connection.ConnectionString = $connsetcionString;
        
        [System.Data.Common.DbCommand]$command = $connection.CreateCommand();
    }

    process {
        $command.CommandText = $query;
        
        [System.Data.Common.DataAdapter]$adapter = $null;
        if ($isSQLServer.IsPresent) {
            $adapter = New-Object -TypeName System.Data.SqlClient.SqlDataAdapter($command);
        }
        else {
            $adapter = New-Object -TypeName System.Data.OleDb.OleDbDataAdapter($command);
        }

        [System.Data.DataSet]$dataSet = New-Object -TypeName System.Data.DataSet;
        $adapter.Fill($dataSet);
    }
}