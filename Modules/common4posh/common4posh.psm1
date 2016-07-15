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
			}
			default {
				return $null;		
			}
		}
	}
}