az login                         
az account set --subscription "Visual Studio Enterprise: BizSpark"

Clear
# This section contains baseline information relevant only to my subscription.  Can be modified/deleted as needed
$NoteA = "Need to look at commonizing to minimal OS versions, i.e. migrate all Windows to DataCenter 2016"
$NoteB = "30d Baseline values as of Jan 28, 2018"

$FileDate = (Get-Date).ToString("yyyy-MM-dd_HHmm")
Write $FileDate | Out-File C:\Temp\$($FileDate)_Azure_Status.txt -append

Function AddToBaseline($name, $metric, $value)
{
$Item = New-Object PSObject
$Item | Add-Member NoteProperty -name VM -value $name
$Item | Add-Member NoteProperty -name Metric -value $metric
$Item | Add-Member NoteProperty -name Value -value $value
return $Item
}

$Baselines = New-Object System.Collections.ArrayList
$Baselines += AddToBaseline 'WMDev' 'CPU30d' 1.6
$Baselines += AddToBaseline 'LAZDev' 'CPU30d' 4.88
$Baselines += AddToBaseline 'CygnalDev' 'CPU30d' 0.13
$Baselines += AddToBaseline 'WMReporting' 'CPU30d' 12.1

# End notes section

Write "VM-List" | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$VMTableAzureOutput = az vm list --query "[].{VMName:name, ResGroup:resourceGroup, OSType:storageProfile.imageReference.sku, Size:hardwareProfile.vmSize, Location:location, ID:id}"  --out table
$VMTableAzureOutput | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append

$MyVMList = @()
for ($i = 2; $i -lt $VMTableAzureOutput.Length; $i++)         # First row of table is column headers [0], second row is "-"s [1]
{
   $SplitVals = $VMTableAzureOutput[$i] -split "\s+"
   $MyVMList += $SplitVals[5]                                 #$VMList contains the .ID values in one column
}
Write "`n" | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$NoteA | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append


$OutputTable = New-Object System.Collections.ArrayList
Write-Host -NoNewline "`nCalculating CPU Usage."              #Does not output to Text File
Write "`n`nCalculating CPU Usage..." | Out-File C:\Temp\$($FileDate)_Azure_Status.txt -append
foreach ($SingleVM in $MyVMList)                     #SingleVM is the .id value
{
    $Entry = New-Object System.Object
    $EndTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $Time5MinAgo = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $Time6HrAgo = (Get-Date).AddHours(-6).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $Time12HrAgo = (Get-Date).AddHours(-12).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $Time1DayAgo = (Get-Date).AddDays(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $temp = $SingleVM -split '/'                     #temp is an array with each level of the .id directory tree
    $VMName = $temp[8]                               #short VMName is the last 8th place in directory tree, before leading / counts as 0
    Write-Host -NoNewline "."
    $ReturnedData = az monitor metrics list --resource $SingleVM --metric "Percentage CPU" --interval "PT5M" --start-time $Time5MinAgo --end-time $EndTime --aggregation Average Maximum
    $DataAverage = $ReturnedData | Select-String -pattern 'average'
    $DataAverage = $DataAverage -replace "[^0-9.]",''
    $DataMax = $ReturnedData | Select-String -pattern 'maximum'
    $DataMax = $DataMax -replace "[^0-9.]",''
    $FiveMinCPU = [math]::round($DataAverage,2)
    $FiveMinCPUMax = [math]::round($DataMax,2)
    #intentionally overwrites $data with a new metric call
    Write-Host -NoNewline "."
    $ReturnedData = az monitor metrics list --resource $SingleVM --metric "Percentage CPU" --interval "PT1H" --aggregation Average Maximum
    $DataAverage = $ReturnedData | Select-String -pattern 'average'
    $DataAverage = $DataAverage -replace "[^0-9.]",''
    $DataMax = $ReturnedData | Select-String -pattern 'maximum'
    $DataMax = $DataMax -replace "[^0-9.]",''
    $OneHrCPU = [math]::round($DataAverage,2)
    $OneHrCPUMax = [math]::round($DataMax,2)
    #intentionally overwrites $data with a new metric call
    Write-Host -NoNewline "."
    $ReturnedData = az monitor metrics list --resource $SingleVM --metric "Percentage CPU" --interval "PT6H" --start-time $Time6HrAgo --end-time $EndTime --aggregation Average Maximum
    $DataAverage = $ReturnedData | Select-String -pattern 'average'
    $DataAverage = $DataAverage -replace "[^0-9.]",''
    $DataMax = $ReturnedData | Select-String -pattern 'maximum'
    $DataMax = $DataMax -replace "[^0-9.]",''
    $SixHrCPU = [math]::round($DataAverage,2)
    $SixHrCPUMax = [math]::round($DataMax,2)
    #intentionally overwrites $data with a new metric call
    Write-Host -NoNewline "."
    $ReturnedData = az monitor metrics list --resource $SingleVM --metric "Percentage CPU" --interval "PT12H" --start-time $Time12HrAgo --end-time $EndTime --aggregation Average Maximum
    $DataAverage = $ReturnedData | Select-String -pattern 'average'
    $DataAverage = $DataAverage -replace "[^0-9.]",''
    $DataMax = $ReturnedData | Select-String -pattern 'maximum'
    $DataMax = $DataMax -replace "[^0-9.]",''
    $TwelveHrCPU = [math]::round($DataAverage,2)
    $TwelveHrCPUMax = [math]::round($DataMax,2)
    #intentionally overwrites $data with a new metric call
    Write-Host -NoNewline "."
    $ReturnedData = az monitor metrics list --resource $SingleVM --metric "Percentage CPU" --interval "P1D" --start-time $Time1DayAgo --end-time $EndTime --aggregation Average Maximum
    $DataAverage = $ReturnedData | Select-String -pattern 'average'
    $DataAverage = $DataAverage -replace "[^0-9.]",''
    $DataMax = $ReturnedData | Select-String -pattern 'maximum'
    $DataMax = $DataMax -replace "[^0-9.]",''
    $OneDayCPU = [math]::round($DataAverage,2)
    $OneDayCPUMax = [math]::round($DataMax,2)
    $Entry | Add-Member -MemberType NoteProperty -Name "   VMName   " -Value $VMName
    $Entry | Add-Member -MemberType NoteProperty -Name "5MinCPU / Max" -value ("$($FiveMinCPU)".padleft(8) + " / " + "$($FiveMinCPUMax)".padleft(5))
    $Entry | Add-Member -MemberType NoteProperty -Name "OneHrCPU / Max" -value ("$($OneHrCPU)".padleft(8) + " / " + "$($OneHrCPUMax)".padleft(5))
    $Entry | Add-Member -MemberType NoteProperty -Name "SixHrCPU / Max" -value ("$($SixHrCPU)".padleft(8) + " / " + "$($SixHrCPUMax)".padleft(5))
    $Entry | Add-Member -MemberType NoteProperty -Name "TwelveHrCPU / Max" -value ("$($TwelveHrCPU)".padleft(8) + " / " + "$($TwelveHrCPUMax)".padleft(5))
    $Entry | Add-Member -MemberType NoteProperty -Name "OneDayCPU / Max" -value ("$($OneDayCPU)".padleft(8) + " / " + "$($OneDayCPUMax)".padleft(5))
    $Entry | Add-Member -MemberType NoteProperty -Name "30d Baseline" -value $($Baselines | where-object{$_.VM -eq $VMName -and $_.Metric -eq "CPU30d"} | select -expand "Value")
    $OutPutTable.Add($Entry) | out-null
    Write-Host -NoNewline "."
}
Write-Host "`n"
Write "`n" | Out-File C:\Temp\$($FileDate)_Azure_Status.txt -append
$OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$NoteB | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append

