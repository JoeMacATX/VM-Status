az login                         
az account set --subscription "Visual Studio Enterprise: BizSpark"

# This section contains baseline information relevant only to my subscription.  Can be modified/deleted as needed
$NoteA = "Need to look at commonizing to minimal OS versions, i.e. migrate all Windows to DataCenter 2016"
$NoteB = "30d Baseline values as of Jan 28, 2018"



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

Clear
Write-Host "VM-List"
az vm list --query "[].{VMName:name, ResGroup:resourceGroup, OSType:storageProfile.imageReference.sku, Size:hardwareProfile.vmSize, Location:location, ID:id}"  --out table

$VMListAzureOutput = az vm list --query "[].id"       #Use .id because pulling metrics requires ID value
$MyVMList = @()
for ($i = 1; $i -lt $VMListAzureOutput.Length - 1; $i++)     # Skips VMListAzureOutput[0] which is a left square bracket, and VMListAzureOutput[last] is a right square bracket
{
   $MyVMList += $VMListAzureOutput[$i] -replace '[", ]',''   #$VMList contains the .ID values in one column
}
Write-Host $NoteA


$OutputTable = New-Object System.Collections.ArrayList
Write-Host -NoNewline "`nCalculating CPU Usage."
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
    $Entry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $VMName
    $Entry | Add-Member -MemberType NoteProperty -Name "5MinCPU / Max" -value ("$($FiveMinCPU)".padleft(5) + " / " + "$($FiveMinCPUMax)".padleft(5))
    $Entry | Add-Member -MemberType NoteProperty -Name "OneHrCPU / Max" -value ("$($OneHrCPU)".padleft(5) + " / " + "$($OneHrCPUMax)".padleft(5))
    $Entry | Add-Member -MemberType NoteProperty -Name "SixHrCPU / Max" -value ("$($SixHrCPU)".padleft(5) + " / " + "$($SixHrCPUMax)".padleft(5))
    $Entry | Add-Member -MemberType NoteProperty -Name "TwelveHrCPU / Max" -value ("$($TwelveHrCPU)".padleft(5) + " / " + "$($TwelveHrCPUMax)".padleft(5))
    $Entry | Add-Member -MemberType NoteProperty -Name "OneDayCPU / Max" -value ("$($OneDayCPU)".padleft(5) + " / " + "$($OneDayCPUMax)".padleft(5))
    $Entry | Add-Member -MemberType NoteProperty -Name "30d Baseline" -value $($Baselines | where-object{$_.VM -eq $VMName -and $_.Metric -eq "CPU30d"} | select -expand "Value")
    $OutPutTable.Add($Entry) | out-null
    Write-Host -NoNewline "."
}
Write-Host "`n"
$OutputTable | Format-Table
Write-Host $NoteB

