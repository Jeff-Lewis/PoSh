Clear-Host;
$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent;
$env:PSModulePath = $env:PSModulePath.Insert(0, (Split-Path -Path $here -Parent) + ';');
$name = $MyInvocation.MyCommand.Name.Split('.')[0];
Import-Module $name -Force;

function test0 {
	Write-Host "Test 0: Get modules";
	Get-Module;
}

function Test1 {
	Write-Host "Test 1: Get item by absolute path";
	$item = Get-ItemPath -path 'c:\temp';
	$item -eq $null;
}

function Test2 {
	Write-Host "Test 2: Get item by relatively path";
	$item = Get-ItemPath -Path 'oasibur';
	$item -eq $null;
}

function Test3 {
	Write-Host "Test 3: Get item by relatively path";
	Set-Location -Path 'c:\';
	$item = Get-ItemPath -Path 'windows';
	$item -eq $null;
}

function Test4 {
	Write-Host "Test 4: Get item by relatively path with parent path";
	$item = Get-ItemPath -Path 'windows' -parentPath 'c:' ;
	$item -eq $null;
}

function Test5 {
	Write-Host "Test 5: Get item by relatively path with parent path";
	$item = Get-ItemPath -Path 'oasibur' -parentPath 'c:' ;
	$item -eq $null;
}

function test6 {
	Write-Host "Test 6: path emty string";
	$item = Get-ItemPath -Path '';
	$item -eq $null;
}

Test0;
Test1;
Test2;
Test3;
Test4;
Test5;
Test6;