Login-AzureRMAccount

Clear
# This section contains baseline information relevant only to my subscription.  Can be modified/deleted as needed
$NoteA = "Need to look at commonizing to minimal OS versions, i.e. migrate all Windows to DataCenter 2016"
$NoteB = "30d Baseline values as of Jan 28, 2018`n"
$NoteC = "Network Baselines are 1-day averages from week ending Jan 28, 2018"

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
$Baselines += AddToBaseline 'WMDev' 'CPU30d' '1.60'            # CPU 30d baselines are from Azure 30d graphs, ending Jan 28, 2018
$Baselines += AddToBaseline 'LAZDev' 'CPU30d' '4.88'
$Baselines += AddToBaseline 'CygnalDev' 'CPU30d' '0.13'
$Baselines += AddToBaseline 'WMReporting' 'CPU30d' '12.10'
$Baselines += AddToBaseline 'CygnalDev' 'NetIn_1Day' 68300000    # Net Baselines are 7d / 7 average ending Jan 28, 2018
$Baselines += AddToBaseline 'CygnalDev' 'NetOut_1Day' 63200000   
$Baselines += AddToBaseline 'LAZDev' 'NetIn_1Day' 770000000
$Baselines += AddToBaseline 'LAZDev' 'NetOut_1Day' 1008000000   
$Baselines += AddToBaseline 'WMDev' 'NetIn_1Day' 117700000
$Baselines += AddToBaseline 'WMDev' 'NetOut_1Day' 210000000   
$Baselines += AddToBaseline 'WMReporting' 'NetIn_1Day' 59900000
$Baselines += AddToBaseline 'WMReporting' 'NetOut_1Day' 127600000   

# End notes section

function ConvertBytes($value)
{
if ($value -lt 1000) {return $value.ToString("0")}
if ($value -lt 1000000) {return $($value / 1000).ToString("0.0") + "k"}
if ($value -lt 1000000000) {return $($value / 1000000).ToString("0.0") + "M"}
if ($value -lt 1000000000000) {return $($value / 1000000000).ToString("0.0") + "G"}
if ($value -lt 1000000000000000) {return $($value / 1000000000000).ToString("0.0") + "T"}
return ("Err Conversion")
}

Write "`nVM-List" | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$VMList = Get-AzureRmVM
$MyVMArray = New-Object System.Collections.ArrayList
foreach ($vm in $VMList)
{
    $Entry = New-Object System.Object
    $Entry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $vm.Name
    $Entry | Add-Member -MemberType NoteProperty -Name "ResGroup" -Value $vm.ResourceGroupName
    $Entry | Add-Member -MemberType NoteProperty -Name "OSType" -Value $vm.storageProfile.imageReference.sku
    $Entry | Add-Member -MemberType NoteProperty -Name "Size" -Value $vm.HardwareProfile.VmSize
    $Entry | Add-Member -MemberType NoteProperty -Name "Location" -Value $vm.Location
    $Entry | Add-Member -MemberType NoteProperty -Name "ID" -Value $vm.Id

    $MyVMArray.Add($Entry) | out-null
}

$MyVMArray | Select-Object VMName,ResGroup,OSType,Size | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$NoteA | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append


$My_CPU_OutputTable = New-Object System.Collections.ArrayList
$My_NetIn_OutputTable = New-Object System.Collections.ArrayList
$My_NetOut_OutputTable = New-Object System.Collections.ArrayList
Write-Host -NoNewline "`nCalculating Usage Metrics"              #Does not output to Text File
Write "`n`Usage Metrics..." | Out-File C:\Temp\$($FileDate)_Azure_Status.txt -append
$MetricList = @("Percentage CPU", "Network In", "Network Out")
$EndTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$Time5MinAgo = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$Time1HrAgo = (Get-Date).AddMinutes(-60).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$Time6HrAgo = (Get-Date).AddHours(-6).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$Time12HrAgo = (Get-Date).AddHours(-12).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$Time1DayAgo = (Get-Date).AddDays(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
foreach ($SingleVM in $MyVMArray)                     #SingleVM is the .id value
{
    Write-Host -NoNewline "."
    $CPUEntry = New-Object System.Object
    $NetInEntry = New-Object System.Object
    $NetOutEntry = New-Object System.Object
#next few lines return array of values in order of $MetricList in each of the intervals specified
    $Metrics5MinAvg = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 00:05:00 -MetricName $MetricList -StartTime $Time5MinAgo -EndTime $EndTime -AggregationType Average -WarningAction SilentlyContinue  
    $Metrics5MinMax = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 00:05:00 -MetricName $MetricList -StartTime $Time5MinAgo -EndTime $EndTime -AggregationType Maximum -WarningAction SilentlyContinue
    $Metrics5MinTot = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 00:05:00 -MetricName $MetricList -StartTime $Time5MinAgo -EndTime $EndTime -AggregationType Total -WarningAction SilentlyContinue
    $Metrics1HrAvg = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 01:00:00 -MetricName $MetricList -StartTime $Time1HrAgo -EndTime $EndTime -AggregationType Average -WarningAction SilentlyContinue
    $Metrics1HrMax = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 01:00:00 -MetricName $MetricList -StartTime $Time1HrAgo -EndTime $EndTime -AggregationType Maximum -WarningAction SilentlyContinue
    $Metrics1HrTot = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 01:00:00 -MetricName $MetricList -StartTime $Time1HrAgo -EndTime $EndTime -AggregationType Total -WarningAction SilentlyContinue
    $Metrics6HrAvg = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 06:00:00 -MetricName $MetricList -StartTime $Time6HrAgo -EndTime $EndTime -AggregationType Average -WarningAction SilentlyContinue
    $Metrics6HrMax = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 06:00:00 -MetricName $MetricList -StartTime $Time6HrAgo -EndTime $EndTime -AggregationType Maximum -WarningAction SilentlyContinue
    $Metrics6HrTot = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 06:00:00 -MetricName $MetricList -StartTime $Time6HrAgo -EndTime $EndTime -AggregationType Total -WarningAction SilentlyContinue
    $Metrics12HrAvg = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 12:00:00 -MetricName $MetricList -StartTime $Time12HrAgo -EndTime $EndTime -AggregationType Average -WarningAction SilentlyContinue
    $Metrics12HrMax = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 12:00:00 -MetricName $MetricList -StartTime $Time12HrAgo -EndTime $EndTime -AggregationType Maximum -WarningAction SilentlyContinue
    $Metrics12HrTot = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 12:00:00 -MetricName $MetricList -StartTime $Time12HrAgo -EndTime $EndTime -AggregationType Total -WarningAction SilentlyContinue
    $Metrics1DayAvg = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 24:00:00 -MetricName $MetricList -StartTime $Time1DayAgo -EndTime $EndTime -AggregationType Average -WarningAction SilentlyContinue
    $Metrics1DayMax = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 24:00:00 -MetricName $MetricList -StartTime $Time1DayAgo -EndTime $EndTime -AggregationType Maximum -WarningAction SilentlyContinue
    $Metrics1DayTot = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 24:00:00 -MetricName $MetricList -StartTime $Time1DayAgo -EndTime $EndTime -AggregationType Total -WarningAction SilentlyContinue
#CPU values are from [0] as it is first element in $MetricList
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_5_Min / Max" -value ($($Metrics5MinAvg[0].data.average).ToString("0.00") + " / " + $($Metrics5MinMax[0].data.maximum).ToString("0.00"))     
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_1_Hr / Max" -value ($($Metrics1HrAvg[0].data.average).ToString("0.00") + " / " + $($Metrics1HrMax[0].data.maximum).ToString("0.00"))
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_6_Hr / Max" -value ($($Metrics6HrAvg[0].data.average).ToString("0.00") + " / " + $($Metrics6HrMax[0].data.maximum).ToString("0.00"))
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_12_Hr / Max" -value ($($Metrics12HrAvg[0].data.average).ToString("0.00") + " / " + $($Metrics12HrMax[0].data.maximum).ToString("0.00"))
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_1_Day / Max" -value ($($Metrics1DayAvg[0].data.average).ToString("0.00") + " / " + $($Metrics1DayMax[0].data.maximum).ToString("0.00"))
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_30d Baseline" -value $($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "CPU30d"} | select -expand "Value")
    $My_CPU_OutputTable.Add($CPUEntry) | out-null
#Net entries are from [1] and [2]
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_5_Min In/BPS" -value ((ConvertBytes $Metrics5MinTot[1].data.total) + " / " + (ConvertBytes ($Metrics5MinTot[1].data.total / 300)))     
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_1_Hr In/BPS" -value ((ConvertBytes $Metrics1HrTot[1].data.total) + " / " + (ConvertBytes ($Metrics1HrTot[1].data.total / 3600)))
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_6_Hr In/BPS" -value ((ConvertBytes $Metrics6HrTot[1].data.total) + " / " + (ConvertBytes ($Metrics6HrTot[1].data.total / 21600)))
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_12_Hr In/BPS" -value ((ConvertBytes $Metrics12HrTot[1].data.total) + " / " + (ConvertBytes ($Metrics12HrTot[1].data.total / 43200)))
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_1_Day In/BPS" -value ((ConvertBytes $Metrics1DayTot[1].data.total) + " / " + (ConvertBytes ($Metrics1DayTot[1].data.total / 86400)))
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_1d Baseline" -value (ConvertBytes ($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "NetIn_1Day"} | select -expand "Value"))
    $My_NetIn_OutputTable.Add($NetInEntry) | out-null
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_5_Min Out/BPS" -value ((ConvertBytes $Metrics5MinTot[2].data.total) + " / " + (ConvertBytes ($Metrics5MinTot[2].data.total / 300)))     
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_1_Hr Out/BPS" -value ((ConvertBytes $Metrics1HrTot[2].data.total) + " / " + (ConvertBytes ($Metrics1HrTot[2].data.total / 3600)))
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_6_Hr Out/BPS" -value ((ConvertBytes $Metrics6HrTot[2].data.total) + " / " + (ConvertBytes ($Metrics6HrTot[2].data.total / 21600)))
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_12_Hr Out/BPS" -value ((ConvertBytes $Metrics12HrTot[2].data.total) + " / " + (ConvertBytes ($Metrics12HrTot[2].data.total / 43200)))
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_1_Day Out/BPS" -value ((ConvertBytes $Metrics1DayTot[2].data.total) + " / " + (ConvertBytes ($Metrics1DayTot[2].data.total / 86400)))
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_1d Baseline" -value (ConvertBytes ($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "NetOut_1Day"} | select -expand "Value"))
    $My_NetOut_OutputTable.Add($NetOutEntry) | out-null
}
Write-Host "`n"
Write "`n" | Out-File C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_CPU_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$NoteB | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_NetIn_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_NetOut_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$NoteC| Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append