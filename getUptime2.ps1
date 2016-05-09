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

Function Handle-Job($job){
		$holder = Receive-Job -id $job.id
		if($job.state -eq "Stopped"){
			$holder.Details = "WMI Timeout"
		}
		$holder | Select Server,Lastboot,Uptime,Details | Export-Csv $fileName -noTypeInformation -append
		Write-Host $holder.server
		Remove-Job -id $job.id
}

Workflow Timeout-Job(){
	$now = Get-Date
	foreach -parallel ($job in @(Get-Job -State Running)) {
		if ($now - (Get-Job -Id $job.id).PSBeginTime -gt [TimeSpan]::FromSeconds(30)) {
			Sequence{
				Wait-Job -id $job.id -timeout 5
				Stop-Job -id $job.id
				Handle-Job($job)
			}
		}
	}
}

$getServerInfo = {
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
					$upString = [string]$Uptime.Days + ":" + $Uptime.Hours + ":" + $uptime.Minutes + ":" + $uptime.Seconds
					
					$serverInfo = New-Object -TypeName PSObject -Property @{
						Server = $system
						LastBoot = $LastBootUpTime
						Uptime = $upString
						Details = $ErrorMessage
					}
			}
				Catch {
					$ErrorMessage = $_.Exception.Message
					$serverInfo = New-Object -TypeName PSObject -Property @{
						Server = $system
						LastBoot = $LastBootUpTime
						Uptime = $upString
						Details = $ErrorMessage
					}
				}
	}	
	
	else{
		$ErrorMessage = 'Server is Offline'
			$serverInfo = New-Object -TypeName PSObject -Property @{
				Server = $system
				LastBoot = $LastBootUpTime
				Uptime = $upString
				Details = $ErrorMessage
			}

	}
	return $serverInfo
}

$serverList = Get-Content -Path (Get-FileName)
$fileName = Save-File $fileName
$i = 0
$j = 0
$erroractionpreference = "SilentlyContinue"
$jobs = @()
$output = @()
$maxJobs = 32

get-job | Remove-Job | out-null

foreach ($system in $serverList) {
	while ((Get-Job -State Running).Count -ge $maxJobs) {
		Timeout-Job | Out-Null
    }
	$jobs += Start-Job -ScriptBlock $getServerInfo -ArgumentList $system
	$i++
	Write-Progress -id 1 -activity "Starting Job $i of $($serverList.count)" -percentComplete ($i / $serverList.Count*100) 
}

while (@(Get-Job -State Running)) {
	Timeout-Job | Out-Null
}

$output = get-job
	
foreach($job in $output){
	Handle-Job($job)
	$j++
	Write-Progress -id 2 -activity "Completing Job $j of $($output.count)" -percentComplete ($j / $output.Count*100)
	
}