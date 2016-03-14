New-Variable -Name zbin -Scope script;

$root = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

switch ([Environment]::Is64BitOperatingSystem) {
    ($true) {
        $script:zbin = Join-Path -Path ($root) -ChildPath '7z\x64\7za.exe';
    }
    default {
        $script:zbin = Join-Path -Path ($root) -ChildPath '7z\7za.exe';
    }
}

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
        [string]$workDir
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
        $psi.RedirectStandardError = $true;

        # Creating process object
        $p = New-Object -TypeName System.Diagnostics.Process;
        $p.StartInfo = $psi;

        # Creating string builders to store stdout and stderr
        $stdOutBuilder = New-Object -TypeName System.Text.StringBuilder;
        $stdErrBuilder = New-object -TypeName System.Text.StringBuilder;

        # Adding event handers for stdout and stderr
        $sciptBlock = {
            if(! [String]::IsNullOrEmpty($EventArgs.Data)) {
                $Event.MessageData.AppendLine($EventArgs.Data);
                Write-Host -Object $EventArgs.Data;
                #Out-Default -InputObject $EventArgs.Data;
            }
        }
        $scriptBlock2 = {
            param (
                [System.Object]$sender,
                [System.Diagnostics.DataReceivedEventArgs] $e
            )

            try {
                [System.Threading.Monitor]::Enter($Event.MessageData);
                Write-Host -ForegroundColor Yellow -Object $e.Data;
                [void](($Event.MessageData).AppendLine($e.Data));
            }
            catch {
                Write-Host -ForegroundColor Red 'error';
            }
            finaly {
                [System.Threading.Monitor]::Exit($Event.MessageData);
            }
        }

        $stdOutEvent = Register-ObjectEvent -InputObject $p -Action $sciptBlock -EventName 'OutputDataReceived' -MessageData $stdOutBuilder;
        $stdErrEvent = Register-ObjectEvent -InputObject $p -Action $sciptBlock -EventName 'ErrorDataReceived' -MessageData $stdErrBuilder;

        # Starting process
        [void]$p.Start();
        $p.BeginOutputReadLine();
        $p.BeginErrorReadLine();
        $p.WaitForExit();

        # Unregistering events to retrieve process output.
        Unregister-Event -SourceIdentifier $stdOutEvent.Name;
        Remove-Event -SourceIdentifier $stdOutEvent.Name;

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
            }
        )
        return $result;
    }

}

function Create-7zipper {
	[cmdletbinding()]
	param(
		[parameter()]
		[string]$path = $script:zbin
	)
	
	begin {
		if (Test-Path $path) {
				$zipper = New-Object -TypeName psobject;
		}
		else {
			trow New-Object System.IO.FileNotFoundException('Archiver bin file not found', $path);
		}
	}
	process {
		$zipper | 
			Add-Member -MemberType NoteProperty -Name item -Value (Get-Item -Path $path) -PassThru |
			Add-Member -MemberType NoteProperty -Name error -Value '' -PassThru |
			Add-Member -MemberType NoteProperty -Name args -Value '' -PassThru |
			Add-Member -MemberType NoteProperty -Name out -Value '' -PassThru |
			Add-Member -MemberType ScriptMethod -Name Run -Value {
                
                $this.out = '';
                $this.error = $null;
                $result = Invoke-Executable -fileName $this.item.FullName -arg $this.args -workDir (Get-Item -Path '.\').FullName;
                $this.error = $result.ExitCode;
                $this.out = $result.StdOut;
			} -PassThru |
            Add-Member -MemberType ScriptMethod -Name AddSwitch -Value {
                param(
                    [string]$switch
                )

                $this.args = $this.args + " $switch";
            }
		return $zipper;
	}
}

function Benchmark-7z {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true)]
		[psobject]$zipper,
		
		[parameter()]
		[int]$iterations = 1
	)
	process {
		$zipper.args = "b $iterations";
		$zipper.Run();
		return $zipper;
	}
}

function List-7z {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true)]
		[psobject]$zipper,
		
		[parameter()]
		[string]$path
	)
	process {
		$zipper.args = "l $path";
		$zipper.Run();
		return $zipper;
	}
}

function Test-7z {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true)]
		[psobject]$zipper,
		
		[parameter()]
		[string]$archive,
		
		[parameter()]
		[string]$files = '*',
		
		[parameter()]
		[string]$includeArchives,
		
		[parameter()]
		[switch]$disableParsingOfArchiveName,
		
		[parameter()]
		[string]$include,
		
		[parameter()]
		[string]$password,
		
		[parameter()]
		[switch]$recurse,
		
		[parameter()]
		[string]$exclude
	)
	
	process {
		$zipper.args = "t $archive $files";
		switch ($true) {
			{$includeArchives.Length -ne 0} {
				$zipper.AddSwitch("-ai$includeArchives");
			}
            {$disableParsingOfArchiveName.IsPresent} {
                $zipper.Addswitch('-an');
            }
            {$include.Length -ne 0} {
                $zipper.AddSwitch("-i$include");
            }
            {$exclude.Length -ne 0} {
                $zipper.AddSwitch("-x$exclude");
            }
            {$password.Length -ne 0} {
                $zipper.AddSwitch("-p$password");
            }
            {$recurse.IsPresent} {
                $zipper.AddSwitch('-r');
            }
		}
		$zipper.Run();
		return $zipper;
	}
}

function Extract-7z {
    [cmdletbinding()]
    param(
        [parameter(Mandatory = $true)]
        [psobject]$zipper,

        [parameter()]
        [string]$archive,

        [parameter()]
        [switch]$fullPath,

        [parameter()]
        [string]$out,

        [parameter()]
        [string]$password,

        [parameter()]
        [switch]$recurse,

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
                $zipper.args = "x -y $archive";
            }
            default {
                $zipper.args = "e -y $archive";
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
            {$recurse.IsPresent} {
                $zipper.AddSwitch('-r');
            }
            {$type.Length -ne 0} {
                $zipper.AddSwitch("-t$type");
            }
        }

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