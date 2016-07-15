New-Variable -Name zbin -Scope script;

$root = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

switch ([Environment]::Is64BitOperatingSystem) {
	($true) {
		$script:zbin = Join-Path -Path ($root) -ChildPath '7z\x64\7z.exe';
	}
	default {
		$script:zbin = Join-Path -Path ($root) -ChildPath '7z\7z.exe';
	}
}

<#
.SYNOPSIS
Invoke executable binary programm
.DESCRIPTION
Execute program with args.
.PARAMETER fileName
Name of executable file.
.PARAMETER arg
Arguments to run exe file.
.PARAMETER verb
//TODO
.PARAMETER workDir
Working directory (workspace).
.PARAMETER verbouse
Switch to show output text to console.
.PARAMETER priority
Priority running process
.INPUTS
You can`t pipe objects to this cmdlet
.OUTPUTS
Object. Returns stdOut and stdErr stream. Also return start/stop process time, 
exit code and startup args.
.EXAMPLE
Invoke-Executable -fileName 'c:\example.exe' -arg '-v -h' -workDir (Get-Item -Path '.\').FullName -verbouse;
 
#>
function Invoke-Executable {
	[cmdletbinding()]
	param(
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$fileName,		
		
		[parameter()]
		[string]$arg,		
		
		[parameter()]
		[string]$verb,		
		
		[parameter()]
		[string]$workDir,		
		
		[parameter()]
		[switch]$verbouse,		
		
		[parameter()]
		[ValidateSet('Idle', 'Normal', 'High', 'RealTime')]
		[string]$priority = 'Normal',
		
		[parameter()]
		[System.Text.Encoding]$encoding = [System.Text.Encoding]::UTF8
	)
	process{
		# Setting process invocation parameters
		$psi = New-Object -TypeName System.Diagnostics.ProcessStartInfo;
		$psi.FileName = $fileName;
		switch ($true) {
			{![string]::IsNullOrEmpty($arg)} {
				$psi.Arguments = $arg;
			}
			{![string]::IsNullOrEmpty($verb)} {
				$psi.Verb = $verb;
			}
			{![string]::IsNullOrEmpty($workDir)} {
				$psi.WorkingDirectory = $workDir;
			}
		}
		$psi.CreateNoWindow = $true;
		$psi.UseShellExecute = $false;
		$psi.RedirectStandardOutput = $true;
		$psi.StandardOutputEncoding = $encoding;
		$psi.RedirectStandardError = $true;			
		$psi.StandardErrorEncoding = $encoding;
			
		# Creating process object
		$p = New-Object -TypeName System.Diagnostics.Process;
		$p.StartInfo = $psi;
		switch ($priority) {
			'Idle' { $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle; }
			'Normal' { [System.Diagnostics.ProcessPriorityClass]::Normal; }
			'High' { [System.Diagnostics.ProcessPriorityClass]::High; }
			'RealTime' { [System.Diagnostics.ProcessPriorityClass]::RealTime; }
		}
			
		# Creating string builders to store stdout and stderr
		$stdOutBuilder = New-Object -TypeName System.Text.StringBuilder;
		$stdErrBuilder = New-object -TypeName System.Text.StringBuilder;
			
		# Adding event handers for stdout and stderr
		$stdHandler = {
			if(! [String]::IsNullOrEmpty($EventArgs.Data)) {
				$Event.MessageData[0].AppendLine($EventArgs.Data);
				# Check -verbouse
				if ($Event.Messagedata[1].IsPresent) {
					Write-Host $EventArgs.Data;
				}
			}
		}
		
		$stdOutEvent = Register-ObjectEvent -InputObject $p -Action $stdHandler -EventName 'OutputDataReceived' -MessageData $stdOutBuilder, $verbouse;
		$stdErrEvent = Register-ObjectEvent -InputObject $p -Action $stdHandler -EventName 'ErrorDataReceived' -MessageData $stdErrBuilder, $verbouse;
			
		# Starting process
		[void]$p.Start();
		$p.BeginOutputReadLine();
		$p.BeginErrorReadLine();    
		while (!$p.HasExited) {
			$p.Refresh();
			Start-Sleep -Seconds 1;
		}
		
		$p.CancelOutputRead();
		$p.CancelErrorRead();
			
		# Unregistering events to retrieve process output.
		Unregister-Event -SourceIdentifier $stdOutEvent.Name;
		Unregister-Event -SourceIdentifier $stdErrEvent.Name;
			
		$result = New-Object -TypeName psobject -Property (
			@{
				'FileName' = $p.StartInfo.FileName;
				'Args' = $p.StartInfo.Arguments;
				'WorkingDirectory' = $p.StartInfo.WorkingDirectory;
				'StartTime' = $p.StartTime;
				'ExitTime' = $p.ExitTime;
				'ExitCode' = $p.ExitCode;
				'StdOut' = $stdOutBuilder.ToString();
				'StdErr' = $stdErrBuilder.ToString();
				'Verbouse' = $verbouse;
			}
		);
		
		return $result;
	}
}

<#
.SYNOPSIS
Create 7z object.
.DESCRIPTION
Creating an object that handles the file.
.PARAMETER path
Path to binary file.
.INPUTS
You can`t pipe object to cmdlets
.OUTPUTS
Object with args, exit and out stream parameters. Also create function 
Run - execute arch binary.
.EXAMPLE
Create-7zipper -path c:\7za.exe
#>
function Create-7zipper {
	[cmdletbinding()]
	param(
		[parameter()]
		[string]$path = $script:zbin
	)
	
	begin {
		if (!(Test-Path $path)) {
			trow New-Object System.IO.FileNotFoundException('Archiver bin file not found', $path);				
		}
	}
	process {
		$process = New-Object -TypeName psobject -Property (
			@{
				'args' = $null;
				'out' = $null;
				'startTime' = $null;
				'exitCode' = $null;
				'exitTime' = $null;
				'verbouse' = [switch]$null;
			}
		);
		$zipper = New-Object -TypeName psobject |
			Add-Member -MemberType NoteProperty -Name item -Value (Get-Item -Path $path) -PassThru |
			Add-Member -MemberType NoteProperty -Name process -Value $process -PassThru |		
			Add-Member -MemberType ScriptMethod -Name Run -Value {
				$this.process = Invoke-Executable -fileName $this.item.FullName -arg $this.process.args -workDir (Get-Item -Path '.\').FullName -verbouse:$this.process.verbouse;     
			} -PassThru |
			Add-Member -MemberType ScriptMethod -Name AddSwitch -Value {
				param(
					[string]$switch
				)

					$this.process.args = $this.process.args + " $switch";
			} -PassThru;

		return $zipper;
	}
}

<#
.SYNOPSIS
Benchmark on computer.
.DESCRIPTION
Test speed archive on computer.
.PARAMETER zipper
Zip object, created of cmdlet Create-7zipper.
.PARAMETER iterations
Number of iterations.
.PARAMETER quiet
Don't show stdout after run.
.INPUTS
You can`t pipe object to cmdlets
.OUTPUTS
Object with args, exit and out stream $_.process.out
Fill $zipper.process.
.EXAMPLE
Benchmark-7z -zipper $7z
#>
function Benchmark-7z {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true)]
		[psobject]$zipper,
		
		[parameter()]
		[int]$iterations = 1,
        
    [parameter()]
    [switch]$quiet
	)
	process {
		$zipper.process.verbouse = !$quiet;
		$zipper.process.verbouse = $verbouse;
		$zipper.process.args = "b $iterations";
		$zipper.Run();
		return $zipper;
	}
}

<#
.SYNOPSIS
List archive
.DESCRIPTION
List archive file.
.PARAMETER zipper
Zip object, created of cmdlet Create-7zipper.
.PARAMETER archive
Path to archive file.
.PARAMETER quiet
Don't show stdout after run.
.INPUTS
String. You can use pipeline from path to archive.
.OUTPUTS
Object with args, exit and out stream $_.process.out
Fill $zipper.process.
#>
function List-7z {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true)]
		[psobject]$zipper,
		
		[parameter(ValueFromPipeline = $true)]
		[Alias('path')]
		[string]$archive,
		
		[Parameter()]
		[string]$password,
		
		[Parameter()]
		[switch]$quiet
	)
	process {
		$zipper.process.verbouse = !$quiet;
		$zipper.AddSwitch("l $archive");
		switch ($true) {
			{$password.Length -ne 0} {
				$zipper.AddSwitch("-p$password");
			}
		}
		
		$zipper.Run();
		return $zipper;
	}
}

<#
.SYNOPSIS
Test archive file.
.DESCRIPTION
Simple test archive files.
.PARAMETER zipper
Zip object, created of cmdlet Create-7zipper.
.PARAMETER archive
Path to archive file.
.PARAMETER files
wildcard of files in archive for testing. By default use all files '*' wildcard.
.PARAMETER password
Specifies password.
.PARAMETER quiet
Don't show stdout after run.
.INPUTS
String. You can use pipeline from path to archive.
.OUTPUTS
Object with args, exit and out stream $_.process.out
Fill $zipper.process.
#>
function Test-7z {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true)]
		[psobject]$zipper,
		
		[parameter(ValueFromPipeline = $true)]
		[Alias('path')]
		[string]$archive,
		
		[parameter()]
		[string]$files = '*',
		
		[parameter()]
		[string]$password
	)
	
	process {
		$zipper.process.verbouse = !$quiet;
		$zipper.AddSwitch("t $archive $files");
		switch ($true) {
			{$password.Length -ne 0} {
				$zipper.AddSwitch("-p$password");
			}
		}
		$zipper.Run();
		return $zipper;
	}
}

<#
.SYNOPSIS
Extract archive file.
.DESCRIPTION
Extracts files from an archive to the current directory or to the output directory.
The output directory can be specified by -out (Set Output Directory) parameter.
This cmdlet copies all extracted files to one directory.
.PARAMETER zipper
Zip object, created of cmdlet Create-7zipper.
.PARAMETER archive
Path to archive file.
.PARAMETER fullPath
If you want extract files with full paths, you must use this parameter.
.PARAMETER out
Specifies a destination directory where files are to be extracted.
.PARAMETER password
Specifies password.
.PARAMETER quiet
Don't show stdout after run.
.PARAMETER overwrite
Specifies the overwrite mode during extraction, to overwrite files already present on disk.
.PARAMETER type
Specifies the type of archive. 
.INPUTS
String. You can use pipeline from path to archive.
.OUTPUTS
Object with args, return $zipper and out stream $zipper.process.out
Fill $zipper.process
#>
function Extract-7z {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true)]
		[psobject]$zipper,
			
		[parameter(ValueFromPipeline = $true)]
		[Alias('path')]
		[string]$archive,	
		
		[parameter()]
		[switch]$fullPath,	
		
		[parameter()]
		[Alias('destination')]
		[string]$out,	
		
		[parameter()]
		[string]$password,
		
		[parameter()]
		[switch]$quiet,	
		
		[parameter()]
		[ValidateSet('All', 'Skip', 'RenameExtracting', 'RenameExisting')]
		[string]$overwrite = 'Skip',	
		
		[parameter()]
		[string]$type
	)
	process {
		#fullpath param
		switch ($fullPath.IsPresent) {
			$true {
				$zipper.AddSwitch("x -y $archive");
			}
			default {
				$zipper.AddSwitch("e -y $archive");
			}
		}
		
		#advanced parameters
		switch ($true) {
			{$out.Length -ne 0} {
				$zipper.AddSwitch("-o$out");
			}
			{$password.Length -ne 0} {
				$zipper.AddSwitch("-p$password");
			}
			{$type.Length -ne 0} {
				$zipper.AddSwitch("-t$type");
			}
		}
		
		#overwrite mode
		switch ($overwrite) {
			'All' {
				$zipper.AddSwitch('-oao');
				break;
			}
			'Skip' {
				$zipper.AddSwitch('-aos');
				break;
			}
			'RenameExtracting' {
				$zipper.AddSwitch('-aou');
				break;
			}
			'RenameExisting' {
				$zipper.AddSwitch('-aot');
				break;
			}
		}
		
		$zipper.Run();
		return $zipper;
	}
}
