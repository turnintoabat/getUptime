<#

Script created by Brendan Sturges, reach out if you have any issues.
This script queries a file the user chooses and checks all servers within for current uptime & if it's zombied

#>

Function Get-FileName($initialDirectory){   
	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
	Out-Null

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

#Open a file dialog window to get the source file
$serverList = Get-Content -Path (Get-FileName)

#open a file dialog window to save the output
$fileName = Save-File $fileName
$errorActionPreference = "SilentlyContinue"
$i = 0

$LastBootUpTime = [wmi]''
$LastBootUpTime.psbase.options.timeout = '0:0:5'
		
		
foreach($server in $serverList) {
	Try {
				#####define as null to prevent repeat data####
		$lastBoot = ''
		$currentTime = ''
		$uptime = ''
		$ErrorMessage = ''
		$Domain = ''

		$pingAndReturn = (ping $server -n 1).split('.')
		$domain = $pingAndReturn[2].toUpper()
		
		$LastBootUpTime = [wmi]''
		$LastBootUpTime.psbase.options.timeout = '0:0:5'
		
		$LastBootUpTime = Get-WmiObject Win32_OperatingSystem -ComputerName $server
		
		$results = $LastBootUpTime | Select {$_.ConvertToDateTime($_.LastBootUpTime)}
		
		#$results = $LastBootUpTime | Select $_.LastBootUpTime
		
		#$results = [System.Management.ManagementDateTimeconverter]::ToDateTime($LastBootUpTime.lastbootuptime)
		
		$lastBoot = $results.{$_.ConvertToDateTime($_.LastBootUpTime)}
		$currentTime = Get-Date
		$diff = $currentTime - $lastBoot
		#$diff = New-TimeSpan -start $lastBoot -end Get-Date
		$uptime = ($diff.Days).toString() + ":" + ($diff.Hours).toString() + ":" + ($diff.minutes).toString() + ":" + ($diff.seconds).toString()
	
		$props = [ordered]@{
			'Server' = $server
			'Domain' = $domain
			'Last Boot' = $lastBoot
			'Uptime (D:H:M:S)' = $uptime
			'Details' = $ErrorMessage
			
		} 
		$obj = New-Object -TypeName PSObject -Property $props
	}

	Catch {
		$ping = ''
		$ping = Test-Connection -ComputerName $server -Count 1 -Quiet
		if($ping)
			{
			$ErrorMessage = $_.Exception.Message
			}
		else
			{
			$ErrorMessage = 'Server is Offline'
				}
			
		$props = [ordered]@{
			'Server' = $server
			'Domain' = $domain
			'Last Boot' = $lastBoot
			'Uptime (D:H:M:S)' = $uptime
			'Details' = $ErrorMessage
			}
			
		$obj = New-Object -TypeName PSObject -Property $props
	
	}
	Finally {
		$data = @()
		$data += $obj
		$data | Export-Csv $fileName -noTypeInformation -append	
	}
	$i++
	Write-Progress -activity "Checking server $i of $($serverList.count)" -percentComplete ($i / $serverList.Count*100)	
}


