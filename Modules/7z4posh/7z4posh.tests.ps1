Clear-Host;
$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent;
$env:PSModulePath = $env:PSModulePath.Insert(0, (Split-Path -Path $here -Parent) + ';');
$name = $MyInvocation.MyCommand.Name.Split('.')[0];
Import-Module $name -Force;

$z = Create-7zipper;
Benchmark-7z -zipper $z -verbouse;
$z;
#$z.process.args = 'b 1';
#$z.RunSync();