Clear-Host;
$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent;
$env:PSModulePath = $env:PSModulePath.Insert(0, (Split-Path -Path $here -Parent) + ';');
$name = $MyInvocation.MyCommand.Name.Split('.')[0];
Import-Module $name -Force;


function test1 {
	Write-Host "Test 1: default benchmark";
	$z = Create-7zipper;
	Benchmark-7z -zipper $z -verbouse;
	$z;
}

function test2 {
	Write-Host "Test 2: List archive";
	$z = Create-7zipper;
	List-7z -zipper $z -path '../../7ztest.7z';
	$z.process;
}

test2;