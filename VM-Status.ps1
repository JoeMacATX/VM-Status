if ([string]::IsNullOrEmpty($(Get-AzureRmContext).Account)) {Login-AzureRmAccount}

Clear
# This section contains baseline information relevant only to my subscription.  Can be modified/deleted as needed
$NoteA = "Need to look at commonizing to minimal OS versions, i.e. migrate all Windows to DataCenter 2016"

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
$Baselines += AddToBaseline 'CygnalDev' 'Read_1Day' 142200     # Disk Baselines are 7d / 7 average ending Jan 28, 2018
$Baselines += AddToBaseline 'CygnalDev' 'Write_1Day' 512900000   
$Baselines += AddToBaseline 'LAZDev' 'Read_1Day' 2006000000
$Baselines += AddToBaseline 'LAZDev' 'Write_1Day' 1921000000   
$Baselines += AddToBaseline 'WMDev' 'Read_1Day' 700000000
$Baselines += AddToBaseline 'WMDev' 'Write_1Day' 8206000000   
$Baselines += AddToBaseline 'WMReporting' 'Read_1Day' 214300000
$Baselines += AddToBaseline 'WMReporting' 'Write_1Day' 9929000000   

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


function Add_RM_Metrics_Strings($array)
{
   $a = New-Object System.Object
   $a | Add-Member -MemberType NoteProperty -Name "Sum" -value 0
   $a | Add-Member -MemberType NoteProperty -Name "Cnt" -value 0
   $a | Add-Member -MemberType NoteProperty -Name "Max" -value 0
   $a | Add-Member -MemberType NoteProperty -Name "Avg" -value 0
   foreach ($entry in $array) {
      $a.sum += $entry.average
      $a.cnt++
      if ($entry.average -gt $a.max) {$a.max = $entry.average}
   }
   $a.avg = $a.sum / $a.cnt
   return ($a)
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
    $VM_Sku = Get-AzureRMVMSize -location $vm.location | ?{ $_.name -eq $vm.HardwareProfile.VmSize }
    $Entry | Add-Member -MemberTYpe NoteProperty -Name "Cores" -value $VM_Sku.NumberOfCores
    $Entry | Add-Member -MemberTYpe NoteProperty -Name "Memory_GB" -value ([math]::Round(($Vm_Sku.MemoryInMB)/1024,1))
    $Entry | Add-Member -MemberType NoteProperty -Name "Location" -Value $vm.Location
    $Entry | Add-Member -MemberType NoteProperty -Name "ID" -Value $vm.Id
    $Entry | Add-Member -MemberType NoteProperty -Name "Pub_IP" -Value ((Get-AzureRmPublicIpAddress -ResourceGroupName $vm.ResourceGroupName).IpAddress)
    $Entry | Add-Member -MemberType NoteProperty -Name "IP_Method" -Value ((Get-AzureRmPublicIpAddress -ResourceGroupName $vm.ResourceGroupName).PublicIpAllocationMethod)

    $MyVMArray.Add($Entry) | out-null
}

$MyVMArray | Select-Object VMName,ResGroup,OSType,Size,Cores,Memory_GB,Pub_IP,IP_Method | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$NoteA | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append


$My_CPU_OutputTable = New-Object System.Collections.ArrayList
$My_NetIn_OutputTable = New-Object System.Collections.ArrayList
$My_NetOut_OutputTable = New-Object System.Collections.ArrayList
$My_DiskRead_OutputTable = New-Object System.Collections.ArrayList
$My_DiskWrite_OutputTable = New-Object System.Collections.ArrayList
Write-Host -NoNewline "`nCalculating Usage Metrics"              #Does not output to Text File
Write "`n`Usage Metrics..." | Out-File C:\Temp\$($FileDate)_Azure_Status.txt -append
$MetricList = @("Percentage CPU", "Network In", "Network Out", "Disk Read Bytes", "Disk Write Bytes")
$Time1DayAgo = (Get-Date).AddDays(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$EndTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

foreach ($SingleVM in $MyVMArray)                     #SingleVM is the .id value
{
    Write-Host -NoNewline "."
    $CPUEntry = New-Object System.Object
    $NetInEntry = New-Object System.Object
    $NetOutEntry = New-Object System.Object
    $DiskReadEntry = New-Object System.Object
    $DiskWriteEntry = New-Object System.Object
    $Metrics = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain 00:01:00 -MetricName $MetricList -StartTime $Time1DayAgo -EndTime $EndTime -AggregationType Average -WarningAction SilentlyContinue
#CPU values are from [0] as it is first element in $MetricList
    Write-Host -NoNewline "."
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[0].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddMinutes(-5).ToUniversalTime().ToString()})
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_5_Min / Max" -value ($($MetricStats.Avg).ToString("0.00") + " / " + $($MetricStats.Max).ToString("0.00"))     
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[0].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddMinutes(-60).ToUniversalTime().ToString()})
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_1_Hr / Max" -value ($($MetricStats.Avg).ToString("0.00") + " / " + $($MetricStats.Max).ToString("0.00"))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[0].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-6).ToUniversalTime().ToString()})
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_6_Hr / Max" -value ($($MetricStats.Avg).ToString("0.00") + " / " + $($MetricStats.Max).ToString("0.00"))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[0].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-12).ToUniversalTime().ToString()})
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_12_Hr / Max" -value ($($MetricStats.Avg).ToString("0.00") + " / " + $($MetricStats.Max).ToString("0.00"))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[0].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-24).ToUniversalTime().ToString()})
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_1_Day / Max" -value ($($MetricStats.Avg).ToString("0.00") + " / " + $($MetricStats.Max).ToString("0.00"))
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_30d Baseline" -value $($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "CPU30d"} | select -expand "Value")
    $My_CPU_OutputTable.Add($CPUEntry) | out-null
#Net entries are from [1] and [2]
    Write-Host -NoNewline "."
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[1].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddMinutes(-5).ToUniversalTime().ToString()})
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_5_Min In/BPS" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 5)))     
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[1].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddMinutes(-60).ToUniversalTime().ToString()})
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_1_Hr In/BPS" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 60)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[1].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-6).ToUniversalTime().ToString()})
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_6_Hr In/BPS" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 360)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[1].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-12).ToUniversalTime().ToString()})
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_12_Hr In/BPS" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 720)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[1].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-24).ToUniversalTime().ToString()})
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_1_Day In/BPS" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 1440)))
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_1d Baseline" -value (ConvertBytes ($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "NetIn_1Day"} | select -expand "Value"))
    $My_NetIn_OutputTable.Add($NetInEntry) | out-null
    Write-Host -NoNewline "."
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[2].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddMinutes(-5).ToUniversalTime().ToString()})
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_5_Min In/BPS" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 5)))     
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[2].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddMinutes(-60).ToUniversalTime().ToString()})
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_1_Hr In/BPS" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 60)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[2].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-6).ToUniversalTime().ToString()})
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_6_Hr In/BPS" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 360)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[2].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-12).ToUniversalTime().ToString()})
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_12_Hr In/BPS" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 720)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[2].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-24).ToUniversalTime().ToString()})
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_1_Day In/BPS" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 1440)))
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_1d Baseline" -value (ConvertBytes ($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "NetOut_1Day"} | select -expand "Value"))
    $My_NetOut_OutputTable.Add($NetOutEntry) | out-null
#Net entries are from [3] and [4]
    Write-Host -NoNewline "."
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[3].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddMinutes(-5).ToUniversalTime().ToString()})
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "DiskRead_5_Min" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 5)))     
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[3].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddMinutes(-60).ToUniversalTime().ToString()})
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "DiskRead_1_Hr" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 60)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[3].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-6).ToUniversalTime().ToString()})
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "DiskRead_6_Hr" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 360)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[3].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-12).ToUniversalTime().ToString()})
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "DiskRead_12_Hr" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 720)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[3].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-24).ToUniversalTime().ToString()})
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "DiskRead_1_Day" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 1440)))
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "Read_1d BL" -value (ConvertBytes ($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "Read_1Day"} | select -expand "Value"))
    $My_DiskRead_OutputTable.Add($DiskReadEntry) | out-null
    Write-Host -NoNewline "."
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[4].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddMinutes(-5).ToUniversalTime().ToString()})
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "DiskWrite_5_Min" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 5)))     
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[4].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddMinutes(-60).ToUniversalTime().ToString()})
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "DiskWrite_1_Hr" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 60)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[4].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-6).ToUniversalTime().ToString()})
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "DiskWrite_6_Hr" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 360)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[4].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-12).ToUniversalTime().ToString()})
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "DiskWrite_12_Hr" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 720)))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[4].data | Where-Object {$_.TimeStamp -gt (Get-Date).AddHours(-24).ToUniversalTime().ToString()})
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "DiskWrite_1_Day" -value ((ConvertBytes $MetricStats.Sum) + " / " + (ConvertBytes ($MetricStats.Sum / 1440)))
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "Write_1d BL" -value (ConvertBytes ($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "Write_1Day"} | select -expand "Value"))
    $My_DiskWrite_OutputTable.Add($DiskWriteEntry) | out-null
}
Write-Host "`n"
Write "`n" | Out-File C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_CPU_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_NetIn_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_NetOut_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_DiskRead_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_DiskWrite_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append

