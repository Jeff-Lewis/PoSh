Clear-Host;
$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent;
$env:PSModulePath = $env:PSModulePath.Insert(0, (Split-Path -Path $here -Parent) + ';');
$name = $MyInvocation.MyCommand.Name.Split('.')[0];
Import-Module $name -Force;

$str = Get-ConnectionString -server '.' -instance 'velo2014' -database 'master' -trustedConnection
Write-Host "Connection string: '$str'";

$query = "sp_who";
$res = Invoke-SQLQuery -connectionString $str -query $query;