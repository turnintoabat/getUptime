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
					$a = ''
					
					$Bootup = $wmiresult.LastBootUpTime
					$LastBootUpTime = [System.Management.ManagementDateTimeconverter]::ToDateTime($Bootup)
					$now = Get-Date
					$Uptime = $now - $lastBootUpTime
					$d = $Uptime.Days
					$h = $Uptime.Hours
					$m = $uptime.Minutes
					$s = $uptime.Seconds
					$a = [string]$d + ":" + $h + ":" + $m + ":" + $s
					
					
					$serverInfo = New-Object -TypeName PSObject -Property @{
						Server = $system
						LastBoot = $LastBootUpTime
						Uptime = $a
						Details = $ErrorMessage
					}
			}
				Catch {
					$ErrorMessage = $_.Exception.Message
					$serverInfo = New-Object -TypeName PSObject -Property @{
						Server = $system
						LastBoot = $LastBootUpTime
						Uptime = $a
						Details = $ErrorMessage
					}
				}
	}	
	
	else{
		$ErrorMessage = 'Server is Offline'
			$serverInfo = New-Object -TypeName PSObject -Property @{
				Server = $system
				LastBoot = $LastBootUpTime
				Uptime = $a
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
	Write-Progress -id 1 -activity "Starting Job $i of $($serverList.count)" -percentComplete ($i / $serverList.Count*100) 
	}

$output = @()
$output = get-job

$finalObject = @()

$j = 0

foreach($job in $output){
	

	$holder = Receive-Job -id $job.id

	while (@(Get-Job -State Running)) {
		$j++
		Write-Progress -id 2 -activity "Finishing Job $j of $($serverList.count)" -percentComplete ($j / $serverList.Count*100) 	
		$now = Get-Date
			foreach ($job in @(Get-Job -State Running)) {
				if ($now - (Get-Job -Id $job.id).PSBeginTime -gt [TimeSpan]::FromSeconds(30)) {
					Stop-Job $job
				}
			}
		Start-Sleep -sec 2
	}

	if(($job.state = "Failed") -or ($job.state = "Stopped")){
		$holder.Details = "WMI Timeout"
	}
	
	$finalObject = $holder | Select Server,Lastboot,Uptime,Details | Export-Csv $fileName -noTypeInformation -append
}

get-job | Remove-Job


