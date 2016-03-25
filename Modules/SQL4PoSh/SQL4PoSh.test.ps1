Clear-Host;
$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent;
$env:PSModulePath = $env:PSModulePath.Insert(0, (Split-Path -Path $here -Parent) + ';');
$name = $MyInvocation.MyCommand.Name.Split('.')[0];
Import-Module $name -Force;

$str = Get-ConnectionString -server '.' -instance 'velo2014' -database 'master' -trustedConnection
Write-Host "Connection string: '$str'";

function test1 {
    Write-Host 'Test 1: single query';
    $res = $null;
    $query = "print 'Hello, World!'";
    $res = Invoke-SQLQuery -connectionString $str -query $query;
    $res;
}

function test2 {
    Write-Host 'Test 2: array query';
    $res = $null;
    $query = @("print 123", "print 'Hello, World!'");
    $res = $query | Invoke-SQLQuery -connectionString $str;
    $res;
}

function test3 {
    Write-Host 'Test 3: multistring query';
    $res = $null;
    $query = @" 
print 'Hello,'
print 'World!'
"@;
    $res = $query | Invoke-SQLQuery -connectionString $str;
    $res;
}

function test4 {
    Write-Host 'Test 4: array multistring query';
    $res = $null;
    $query = @(
@" 
print 'Hello,'
print 'World4!'
"@,
@"
print '123'
print '231'
"@
    )
    $res = $query | Invoke-SQLQuery -connectionString $str;
    $res;
}


test1