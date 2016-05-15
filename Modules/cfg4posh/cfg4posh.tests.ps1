Clear-Host;
$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent;
$env:PSModulePath = $env:PSModulePath.Insert(0, (Split-Path -Path $here -Parent) + ';');
$name = $MyInvocation.MyCommand.Name.Split('.')[0];
Import-Module $name -Force;

function test1 {
	Write-Host "Test 1: Load Cfg"
	$cfg = Get-Config -path .\test.cfg;
	return $cfg;
}

test1;