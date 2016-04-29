Function Get-FileName($initialDirectory){   
	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
	$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
	$OpenFileDialog.initialDirectory = $initialDirectory
	$OpenFileDialog.filter = "All files (*.*)| *.*"
	$OpenFileDialog.ShowDialog() | Out-Null
	$OpenFileDialog.filename
}

Function Save-File([string] $initialDirectory ) {
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "All files (*.*)| *.*"
    $OpenFileDialog.ShowDialog() |  Out-Null
	
	$nameWithExtension = "$($OpenFileDialog.filename).csv"
	return $nameWithExtension
}

$scriptblock = {
	param($system)
	$rtn = Test-Connection -ComputerName $system -Count 1 -Quiet
	if($rtn) {
		$NameSpace = "Root\CIMV2"
		$wmi = [WMISearcher]""
		$wmi.options.timeout = '0:0:5'
		$query = 'Select * from Win32_OperatingSystem'
		$wmi.scope.path = "\\$system\$NameSpace"
		$wmi.query = $query
			Try{
				$wmiresult = $wmi.Get()
					$ErrorMessage = ''
					$lastBootUpTime = ''
					$uptime = ''					
					
					$Bootup = $wmiresult.LastBootUpTime
					$LastBootUpTime = [System.Management.ManagementDateTimeconverter]::ToDateTime($Bootup)
					$now = Get-Date
					$Uptime = $now - $lastBootUpTime
					$d = $Uptime.Days
					$h = $Uptime.Hours
					$m = $uptime.Minutes
					$s = $uptime.Seconds
					$a = "$System Up for: {0} days, {1} hours, {2}.{3} minutes" -f $d,$h,$m,$s
					
					
					$serverInfo = New-Object -TypeName PSObject -Property @{
						Server = $system
						LastBoot = $LastBootUpTime
						Uptime = $Uptime
						Details = $ErrorMessage
					}
			}
				Catch {
					$ErrorMessage = $_.Exception.Message
					$serverInfo = New-Object -TypeName PSObject -Property @{
						Server = $system
						LastBoot = $LastBootUpTime
						Uptime = $Uptime
						Details = $ErrorMessage
					}
				}
	}	
	
	else{
		$ErrorMessage = 'Server is Offline'
			$serverInfo = New-Object -TypeName PSObject -Property @{
				Server = $system
				LastBoot = $LastBootUpTime
				Uptime = $Uptime
				Details = $ErrorMessage
			}

	}
	return $serverInfo
}

$serverList = Get-Content -Path (Get-FileName)
$fileName = Save-File $fileName
$i = 0
$erroractionpreference = "SilentlyContinue"

$jobs = @()
foreach ($system in $serverList) {	
	$jobs += Start-Job -ScriptBlock $scriptblock -ArgumentList $system
	$i++
	Write-Progress -activity "Starting Job $i of $($serverList.count)" -percentComplete ($i / $serverList.Count*100) 
	}
	
#YO ADD THROTTLING TO MAKE THIS NOT SUCK
$jobs | Wait-Job -timeout 120 -Job $jobs > $null
$output = @()


foreach($job in $jobs){
	$output += $_ | Receive-Job $job | Select-Object Server,LastBoot,Uptime,Details
	$output | Export-Csv $fileName -noTypeInformation -append
}

