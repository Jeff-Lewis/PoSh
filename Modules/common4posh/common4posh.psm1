<#
.SYNOPSIS
Advanced Get-Item cmdlet
.DESCRIPTION
Get the item from the relative path of the working directory or by specifying the parent directory.
.PARAMETER path
Item path or name.
.PARAMETER parentPath
Parent item path or name.
.EXAMPLE
$item = Get-ItemPath -path 'c:\temp';
Get item from path c:\temp
.EXAMPLE
$item = Get-ItemPath -Path 'windows' -parentPath 'c:' ;
Get item 'windows' from parent 'c:\'
.INPUTS
System.String. You can input in pipe search name of items.
.OUTPUTS
System.IO.FileInfo
System.IO.DirectoryInfo
System.IO.IOException
#>
function Get-ItemPath {
	
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeLine = $true)]
		[AllowEmptyString()]
		[string]$path,
		
		[Parameter()]
		[string]$parentPath
	)
	
	process {
		switch ($true) {
			{$path.Length -eq 0} {
				return $null;
			} 
			{$path | Test-Path} {
				return $path | Get-Item;
			}
			{$parentPath.Length -ne 0} {
				$joingPath = Join-Path -Path $parentPath -ChildPath $path;
				if ($joingPath | Test-Path) {
					return $joingPath | Get-Item;		
				}
				else {
					throw [System.IO.IOException] "Path $joingPath not found";
					return $null;
				}
			}
			default {
				throw [System.IO.IOException] "Path $path not found";
				return $null;		
			}
		}
	}
}