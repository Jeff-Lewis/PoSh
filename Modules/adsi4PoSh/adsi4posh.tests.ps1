Clear-Host;
$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent;
$env:PSModulePath = $env:PSModulePath.Insert(0, (Split-Path -Path $here -Parent) + ';');
$name = $MyInvocation.MyCommand.Name.Split('.')[0];
Import-Module $name -Force;

function test1 {
	Write-Host "Test 1: get Default";
	$dnc = Get-DefaultDomainNamingContext;
	return $dnc;
}

function test2 {
	Write-Host "Test 2: find one obj by default ";
	$obj = Search-ADSI;
	return $obj;
}

function test3 {
	Write-Host "Test 3: find all obj by subtree ";
	$obj = Search-ADSI -searchScope 'Subtree';
	return $obj;
}

function test4 {
	Write-Host "Test 4: find all obj by default ";
	$obj = Search-ADSI -findAll;
	return $obj;
}

function test5 {
	Write-Host "Test 5: Get-ADSIDirectoryEntry for me";
	$obj = Search-ADSI -filter '(sAMAccountName=sbt-chistyakov-vv)' -searchScope subtree | Get-ADSIDirectoryEntry;
	$obj.GetType().FullName;
	return $obj;
}

function test6 {
	Write-Host "Test 6: memberof for me";
	$obj = Search-ADSI -filter '(sAMAccountName=sbt-chistyakov-vv)' -searchScope subtree | Get-ADSIDirectoryEntry | Get-ADSIDirectoryMemberOf;
	$obj.GetType().FullName;
	return $obj;
}

function test7 {
	Write-Host "Test 7: memberof for me";
	$obj = Search-ADSI -filter '(sAMAccountName=sbt-chistyakov-vv)' -searchScope subtree | Get-ADSIDirectoryEntry | Get-ADSIDirectoryMemberOf;
	$obj.GetType().FullName;
	return $obj;
}

function test8 {
	Write-Host "Test 8: member for group";
	$obj = Search-ADSI -filter '(sAMAccountName=str-gr-quikefx-ift)' -searchScope subtree | Get-ADSIDirectoryEntry | Get-ADSIDirectoryMember;
	$obj.GetType().FullName;
	return $obj;
}

function test9 {
	Write-Host "Test 9: relation";
	$obj = Get-ADSIReleation -property 'DirectReports';
	$obj.GetType().FullName;
	return $obj;
}

function test10 {
	Write-Host "Test 10: relation";
	$obj = Get-ADSIGroupMemberEntry -groupName 'str-gr-quikefx-ift';
	$obj.GetType().FullName;
	return $obj;
}
 
test1;
#test2;
#test3;
#test4;
#test5;
#test6;
#test7
#test8
test9
test10
