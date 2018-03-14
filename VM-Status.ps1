if ([string]::IsNullOrEmpty($(Get-AzureRmContext).Account)) {Login-AzureRmAccount}

Clear

# This section contains baseline information relevant only to my subscription.  Can be modified/deleted as needed
$NoteA = "Need to look at commonizing to minimal OS versions, i.e. migrate all Windows to DataCenter 2016"

Function AddToBaseline($name, $metric, $value)
{
$Item = New-Object PSObject
$Item | Add-Member NoteProperty -name VM -value $name
$Item | Add-Member NoteProperty -name Metric -value $metric
$Item | Add-Member NoteProperty -name Value -value $value
return $Item
}

$Baselines = New-Object System.Collections.ArrayList
$Baselines += AddToBaseline 'CygnalDev' 'CPU_30d' '0.13'                  # Baselines are from Azure 30d graphs, ending Mar 1, 2018
$Baselines += AddToBaseline 'CygnalDev' 'NetIn_30d' 1990000000    
$Baselines += AddToBaseline 'CygnalDev' 'NetOut_30d' 1690000000   
$Baselines += AddToBaseline 'CygnalDev' 'Read_30d' 376200000     
$Baselines += AddToBaseline 'CygnalDev' 'Write_30d' 15350000000   
$Baselines += AddToBaseline 'LAZDev' 'CPU_30d' '8.7'
$Baselines += AddToBaseline 'LAZDev' 'NetIn_30d' 25040000000
$Baselines += AddToBaseline 'LAZDev' 'NetOut_30d' 82980000000   
$Baselines += AddToBaseline 'LAZDev' 'Read_30d' 74880000000
$Baselines += AddToBaseline 'LAZDev' 'Write_30d' 74580000000   
$Baselines += AddToBaseline 'WMDev' 'CPU_30d' '2.22'            
$Baselines += AddToBaseline 'WMDev' 'NetIn_30d' 6380000000
$Baselines += AddToBaseline 'WMDev' 'NetOut_30d' 9230000000   
$Baselines += AddToBaseline 'WMDev' 'Read_30d' 38420000000
$Baselines += AddToBaseline 'WMDev' 'Write_30d' 276860000000   
$Baselines += AddToBaseline 'WMReporting' 'CPU_30d' '8.80'
$Baselines += AddToBaseline 'WMReporting' 'NetIn_30d' 2270000000
$Baselines += AddToBaseline 'WMReporting' 'NetOut_30d' 4140000000   
$Baselines += AddToBaseline 'WMReporting' 'Read_30d' 4780000000
$Baselines += AddToBaseline 'WMReporting' 'Write_30d' 147010000000   

# End notes section

$FileDate = (Get-Date).ToString("yyyy-MM-dd_HHmm")
Write $FileDate | Out-File C:\Temp\$($FileDate)_Azure_Status.txt -append





function ConvertBytes($value)
{
   if ($value -eq $null) {return "No data"}
   if ($value -lt 1000) {return $value.ToString("0")}
   if ($value -lt 1000000) {return $($value / 1000).ToString("0.00") + "k"}
   if ($value -lt 1000000000) {return $($value / 1000000).ToString("0.00") + "M"}
   if ($value -lt 1000000000000) {return $($value / 1000000000).ToString("0.00") + "G"}
   if ($value -lt 1000000000000000) {return $($value / 1000000000000).ToString("0.00") + "T"}
return ("Err Conversion")
}


function Add_RM_Metrics_Strings($array)
{
   $a = New-Object System.Object
   $a | Add-Member -MemberType NoteProperty -Name "Sum" -value 0
   $a | Add-Member -MemberType NoteProperty -Name "Cnt" -value 0
   $a | Add-Member -MemberType NoteProperty -Name "Max" -value 0
   $a | Add-Member -MemberType NoteProperty -Name "Avg" -value 0
   $a | Add-Member -MemberType NoteProperty -Name "Min" -value 5000000000000
   foreach ($entry in $array) {
      $a.sum += $entry.average                        #entry.average is the 5-min timeslice value
      $a.cnt++
      if ($entry.average -gt $a.max) {$a.max = $entry.average}
      if ($entry.average -lt $a.min) {$a.min = $entry.average}
   }
   if ($a.cnt -ne 0) {$a.avg = $a.sum / $a.cnt}
   return ($a)
}

Write "`nVM-List" | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$TimeNow = Get-Date -second 0
Write-Host -NoNewline "."
$VMList = Get-AzureRmVM
Get-AzureRmRecoveryServicesVault -Name "LazBackup" -ResourceGroupName "Laz" | Set-AzureRmRecoveryServicesVaultContext                          #Name of recovery services vault and resource group hard coded

$MyVMArray = New-Object System.Collections.ArrayList
foreach ($vm in $VMList)
{
    $Entry = New-Object System.Object
    $Entry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $vm.Name
    $Entry | Add-Member -MemberType NoteProperty -Name "ResGroup" -Value $vm.ResourceGroupName
    $VMDetails = Get-AzureRmVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
    $Entry | Add-Member -MemberType NoteProperty -Name "Status" -Value $VMDetails.Statuses[1].DisplayStatus
    $Entry | Add-Member -MemberType NoteProperty -Name "OSType" -Value $vm.storageProfile.imageReference.sku
    $Entry | Add-Member -MemberType NoteProperty -Name "Size" -Value $vm.HardwareProfile.VmSize
    $VM_Sku = Get-AzureRMVMSize -location $vm.location | ?{ $_.name -eq $vm.HardwareProfile.VmSize }
    $Entry | Add-Member -MemberTYpe NoteProperty -Name "Cores" -value $VM_Sku.NumberOfCores
    $Entry | Add-Member -MemberTYpe NoteProperty -Name "Memory_GB" -value ([math]::Round(($Vm_Sku.MemoryInMB)/1024,1))
    #$Entry | Add-Member -MemberType NoteProperty -Name "Pub_IP" -Value ((Get-AzureRmPublicIpAddress -ResourceGroupName $vm.ResourceGroupName).IpAddress | Where-Object ($_.Name -eq ($vm.name + "-ip")))
    #$Entry | Add-Member -MemberType NoteProperty -Name "IP_Method" -Value ((Get-AzureRmPublicIpAddress -ResourceGroupName $vm.ResourceGroupName).PublicIpAllocationMethod)
    $IPInfo = Get-AzureRmPublicIpAddress -ResourceGroupName $vm.ResourceGroupName | Where-Object {$_.Name -eq ($vm.name + '-ip')}
    $Entry | Add-Member -MemberType NoteProperty -Name "Pub_IP" -Value $IPInfo.IpAddress
    $Entry | Add-Member -MemberType NoteProperty -Name "IP_Method" -Value $IPInfo.PublicIpAllocationMethod
    $nameContainer = Get-AzureRmRecoveryServicesBackupContainer -ContainerType "AzureVM" -Status "Registered" -FriendlyName $vm.Name
    if ($nameContainer -ne $null) 
        {
        $Backup = Get-AzureRmRecoveryServicesBackupItem -Container $nameContainer -WorkloadType "AzureVM" #| select ContainerName,LatestRecoveryPoint
        $Backup2 = Get-AzureRmRecoveryServicesBackupRecoveryPoint -Item $Backup -StartDate $TimeNow.AddDays(-30).ToUniversalTime() -EndDate $TimeNow.ToUniversalTime()
        $Entry | Add-Member -MemberType NoteProperty -Name "Recent_Backup(ET)" -Value $Backup.LatestRecoveryPoint.AddHours(-5).ToString("yyyy-MM-dd HH:mm:ss")        #Hard code -5 hours for Eastern Time
        $Entry | Add-Member -MemberType NoteProperty -Name "Earliest_Backup(ET)" -Value $Backup2[-1].RecoveryPointTime.AddHours(-5).ToString("yyyy-MM-dd HH:mm:ss")        #Hard code -5 hours for Eastern Time
        }
    Else
        {
        $Entry | Add-Member -MemberType NoteProperty -Name "Recent_Backup(ET)" -Value 'No data'        #Hard code -5 hours for Eastern Time
        $Entry | Add-Member -MemberType NoteProperty -Name "Earliest_Backup(ET)" -Value 'No-data'        #Hard code -5 hours for Eastern Time
        }
    $Entry | Add-Member -MemberType NoteProperty -Name "Location" -Value $vm.Location
    $Entry | Add-Member -MemberType NoteProperty -Name "ID" -Value $vm.Id
    Write-Host -NoNewline "."
    $MyVMArray.Add($Entry) | out-null
}

$MyVMArray | Format-Table * | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append   
$NoteA | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append


$My_CPU_OutputTable = New-Object System.Collections.ArrayList
$My_NetIn_OutputTable = New-Object System.Collections.ArrayList
$My_NetOut_OutputTable = New-Object System.Collections.ArrayList
$My_DiskRead_OutputTable = New-Object System.Collections.ArrayList
$My_DiskWrite_OutputTable = New-Object System.Collections.ArrayList
$My_CreditsRem_OutputTable = New-Object System.Collections.ArrayList
$My_CreditsUsed_OutputTable = New-Object System.Collections.ArrayList
Write-Host -NoNewline "`nCalculating Usage Metrics"              #Does not output to Text File
Write "`n`Usage Metrics..." | Out-File C:\Temp\$($FileDate)_Azure_Status.txt -append
$MetricList = @("Percentage CPU", "Network In", "Network Out", "Disk Read Bytes", "Disk Write Bytes", "CPU Credits Remaining", "CPU Credits Consumed")
$TimeGrain = '00:05:00'
#Run short Metrics query to determine today's data per min - it changes!
$GrainMin = 5
$MinInHour = 60
$MinInDay = 60 * 24
$MinInWeek = 60 * 24 * 7
$MinInMonth = 60 * 24 * 30
$Time30DaysAgo = $TimeNow.AddDays(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$EndTime = $TimeNow.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

foreach ($SingleVM in $MyVMArray)                     #SingleVM is the .id value
{
    Write-Host -NoNewline "."
    $CPUEntry = New-Object System.Object
    $NetInEntry = New-Object System.Object
    $NetOutEntry = New-Object System.Object
    $DiskReadEntry = New-Object System.Object
    $DiskWriteEntry = New-Object System.Object
    $CreditsRemEntry = New-Object System.Object
    $CreditsUsedEntry = New-Object System.Object
# When Get-AzureRMMetric is called with -AggregationType Count, the count per timeslice is returned.  It changes
    $DataPerGrain = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain $TimeGrain -MetricNames $MetricList -StartTime $Time30DaysAgo -EndTime $EndTime -AggregationType Count -WarningAction SilentlyContinue
    $Metrics = Get-AzureRMMetric -ResourceID $SingleVM.ID -timegrain $TimeGrain -MetricNames $MetricList -StartTime $Time30DaysAgo -EndTime $EndTime -WarningAction SilentlyContinue
#CPU values are from [0] as it is first element in $MetricList
    Write-Host -NoNewline "."
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    if ($Metrics[0].data[-1].average -eq $null)
       {
       $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_5Min" -value "No data"
       }
    Else
       {
       $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_5Min" -value ($Metrics[0].data[-1].average.ToString("0.00"))  
       }   
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[0].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddMinutes(-60).ToUniversalTime().ToString()})
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_1Hr(Max)" -value ($($MetricStats.Avg).ToString("0.00") + " (" + $($MetricStats.Max).ToString("0.00") + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[0].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddHours(-6).ToUniversalTime().ToString()})
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_6Hr(Max)" -value ($($MetricStats.Avg).ToString("0.00") + " (" + $($MetricStats.Max).ToString("0.00") + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[0].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddHours(-12).ToUniversalTime().ToString()})
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_12Hr(Max)" -value ($($MetricStats.Avg).ToString("0.00") + " (" + $($MetricStats.Max).ToString("0.00") + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[0].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-1).ToUniversalTime().ToString()})
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_1d(Max)" -value ($($MetricStats.Avg).ToString("0.00") + " (" + $($MetricStats.Max).ToString("0.00") + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[0].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-7).ToUniversalTime().ToString()})
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_1Wk(Max)" -value ($($MetricStats.Avg).ToString("0.00") + " (" + $($MetricStats.Max).ToString("0.00") + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[0].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-30).ToUniversalTime().ToString()})
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_30d(Max)" -value ($($MetricStats.Avg).ToString("0.00") + " (" + $($MetricStats.Max).ToString("0.00")+ ")")
    $CPUEntry | Add-Member -MemberType NoteProperty -Name "CPU_30d(BL)" -value $($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "CPU_30d"} | select -expand "Value")
    $My_CPU_OutputTable.Add($CPUEntry) | out-null
#Net entries are from [1] and [2]
#Net metrics.average are in bytes/sec.  Need to be multiplied by $DataPerGrain, variable number of measurements per minute multiplied by $GrainMin slices.
    Write-Host -NoNewline "."
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "NetIn_5Min(BPS)" -value ((ConvertBytes ($Metrics[1].data[-1].average * $DataPerGrain[1].data[-1].count / $GrainMin))`
                                                             + " (" + (ConvertBytes ($Metrics[1].data[-1].average * $DataPerGrain[1].data[-1].count / $GrainMin / $MinInHour)) + ")")     
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[1].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddMinutes(-60).ToUniversalTime().ToString()})
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "NetIn_1Hr(BPS)" -value ((ConvertBytes ($MetricStats.Avg * $DataPerGrain[1].data[-1].count / $GrainMin * $MinInHour))`
                                                             + " (" + (ConvertBytes ($MetricStats.Avg * $DataPerGrain[1].data[-1].count / $GrainMin / $MinInHour)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[1].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-1).ToUniversalTime().ToString()})
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "NetIn_24Hr(BPS)" -value ((ConvertBytes ($MetricStats.Avg * $DataPerGrain[1].data[-1].count /$GrainMin * $MinInDay))`
                                                             + " (" + (ConvertBytes ($MetricStats.Avg * $DataPerGrain[1].data[-1].count /$GrainMin / $MinInHour)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[1].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-7).ToUniversalTime().ToString()})
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "NetIn_1Wk(BPS)" -value ((ConvertBytes ($MetricStats.Avg * $DataPerGrain[1].data[-1].count / $GrainMin * $MinInWeek))`
                                                             + " (" + (ConvertBytes ($MetricStats.Avg * $DataPerGrain[1].data[-1].count /$GrainMin / $MinInHour)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[1].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-30).ToUniversalTime().ToString()})
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "NetIn_30d(BPS)" -value ((ConvertBytes ($MetricStats.Avg * $DataPerGrain[1].data[-1].count /$GrainMin * $MinInMonth))`
                                                             + " (" + (ConvertBytes ($MetricStats.Avg * $DataPerGrain[1].data[-1].count /$GrainMin / $MinInHour)) + ")")
    $NetInEntry | Add-Member -MemberType NoteProperty -Name "Net_30d(BL)" -value (ConvertBytes ($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "NetIn_30d"} | select -expand "Value"))
    $My_NetIn_OutputTable.Add($NetInEntry) | out-null
    Write-Host -NoNewline "."
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "NetOut_5Min(BPS)" -value ((ConvertBytes ($Metrics[2].data[-1].average * $DataPerGrain[2].data[-1].count / $GrainMin))`
                                                              + " (" + (ConvertBytes ($Metrics[2].data[-1].average * $DataPerGrain[2].data[-1].count / $GrainMin / $MinInHour)) + ")")     
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[2].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddMinutes(-60).ToUniversalTime().ToString()})
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "NetOut_1Hr(BPS)" -value ((ConvertBytes ($MetricStats.Avg * $DataPerGrain[2].data[-1].count / $GrainMin * $MinInHour))`
                                                             + " (" + (ConvertBytes ($MetricStats.Avg * $DataPerGrain[2].data[-1].count / $GrainMin / $MinInHour)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[2].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-1).ToUniversalTime().ToString()})
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "NetOut_24Hr(BPS)" -value ((ConvertBytes ($MetricStats.Avg * $DataPerGrain[2].data[-1].count / $GrainMin * $MinInDay))`
                                                             + " (" + (ConvertBytes ($MetricStats.Avg * $DataPerGrain[2].data[-1].count / $GrainMin / $MinInHour)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[2].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-7).ToUniversalTime().ToString()})
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "NetOut_1Wk(BPS)" -value ((ConvertBytes ($MetricStats.Avg * $DataPerGrain[2].data[-1].count / $GrainMin * $MinInWeek))`
                                                             + " (" + (ConvertBytes ($MetricStats.Avg * $DataPerGrain[2].data[-1].count / $GrainMin / $MinInHour)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[2].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-30).ToUniversalTime().ToString()})
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "NetOut_30d(BPS_" -value ((ConvertBytes ($MetricStats.Avg * $DataPerGrain[2].data[-1].count / $GrainMin * $MinInMonth))`
                                                             + " (" + (ConvertBytes ($MetricStats.Avg * $DataPerGrain[2].data[-1].count / $GrainMin / $MinInHour)) + ")")
    $NetOutEntry | Add-Member -MemberType NoteProperty -Name "Net_30d(BL)" -value (ConvertBytes ($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "NetOut_30d"} | select -expand "Value"))
    $My_NetOut_OutputTable.Add($NetOutEntry) | out-null
#Disk entries are from [3] and [4]; data is already per minute so don't need to multiply by $DataPerGrain.data[-1].countute
    Write-Host -NoNewline "."
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[3].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddMinutes(-5).ToUniversalTime().ToString()})
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "DiskRead_5Min(BPS)" -value ((ConvertBytes ($MetricStats.Sum * $GrainMin)) + " (" + (ConvertBytes ($MetricStats.Avg / 60)) + ")")     
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[3].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddMinutes(-60).ToUniversalTime().ToString()})
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "DiskRead_1Hr(BPS)" -value ((ConvertBytes ($MetricStats.Sum * $GrainMin)) + " (" + (ConvertBytes ($MetricStats.Avg / 60)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[3].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-1).ToUniversalTime().ToString()})
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "DiskRead_24Hr(BPS)" -value ((ConvertBytes ($MetricStats.Sum * $GrainMin)) + " (" + (ConvertBytes ($MetricStats.Avg / 60)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[3].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-7).ToUniversalTime().ToString()})
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "DiskRead_1wk(BPS)" -value ((ConvertBytes ($MetricStats.Sum * $GrainMin)) + " (" + (ConvertBytes ($MetricStats.Avg / 60)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[3].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-30).ToUniversalTime().ToString()})
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "DiskRead_30d(BPS)" -value ((ConvertBytes ($MetricStats.Sum * $GrainMin)) + " (" + (ConvertBytes ($MetricStats.Avg / 60)) + ")")
    $DiskReadEntry | Add-Member -MemberType NoteProperty -Name "Read_30d BL" -value (ConvertBytes ($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "Read_30d"} | select -expand "Value"))
    $My_DiskRead_OutputTable.Add($DiskReadEntry) | out-null
    Write-Host -NoNewline "."
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "VMName" -Value $SingleVM.VMName
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[4].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddMinutes(-5).ToUniversalTime().ToString()})
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "DiskWrite_5Min(BPS)" -value ((ConvertBytes ($MetricStats.Sum * $GrainMin)) + " (" + (ConvertBytes ($MetricStats.Avg / 60)) + ")")     
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[4].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddMinutes(-60).ToUniversalTime().ToString()})
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "DiskWrite_1Hr(BPS)" -value ((ConvertBytes ($MetricStats.Sum * $GrainMin)) + " (" + (ConvertBytes ($MetricStats.Avg / 60)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[4].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-1).ToUniversalTime().ToString()})
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "DiskWrite_24Hr(BPS)" -value ((ConvertBytes ($MetricStats.Sum * $GrainMin)) + " (" + (ConvertBytes ($MetricStats.Avg / 60)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[4].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-7).ToUniversalTime().ToString()})
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "DiskWrite_1wk(BPS)" -value ((ConvertBytes ($MetricStats.Sum * $GrainMin)) + " (" + (ConvertBytes ($MetricStats.Avg / 60)) + ")")
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[4].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-30).ToUniversalTime().ToString()})
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "DiskWrite_30d(BPS)" -value ((ConvertBytes ($MetricStats.Sum * $GrainMin)) + " (" + (ConvertBytes ($MetricStats.Avg / 60)) + ")")
    $DiskWriteEntry | Add-Member -MemberType NoteProperty -Name "Write_30d BL" -value (ConvertBytes ($Baselines | where-object{$_.VM -eq $SingleVM.VMName -and $_.Metric -eq "Write_30d"} | select -expand "Value"))
    $My_DiskWrite_OutputTable.Add($DiskWriteEntry) | out-null
    Write-Host -NoNewline "."
    $CreditsRemEntry | Add-Member -MemberType noteProperty -Name "VMName" -Value $SingleVM.VMName
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[5].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddMinutes(-60).ToUniversalTime().ToString()})
    $CreditsRemEntry | Add-Member -MemberType NoteProperty -Name "CredRem_1Hr(Min-Max)" -value ([string]$MetricStats.Min + " - " + [string]$MetricStats.Max)
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[5].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-1).ToUniversalTime().ToString()})
    $CreditsRemEntry | Add-Member -MemberType NoteProperty -Name "CredRem_24Hr(Mix-Max)" -value ([string]$MetricStats.Min + " - " + [string]$MetricStats.Max)
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[5].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-7).ToUniversalTime().ToString()})
    $CreditsRemEntry | Add-Member -MemberType NoteProperty -Name "CredRem_1wk(Min-Max)" -value ([string]$MetricStats.Min + " - " + [string]$MetricStats.Max)
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[5].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-30).ToUniversalTime().ToString()})
    $CreditsRemEntry | Add-Member -MemberType NoteProperty -Name "CredRem_30d(Min-Max)" -value ([string]$MetricStats.Min + " - " + [string]$MetricStats.Max)
    $My_CreditsRem_OutputTable.Add($CreditsRemEntry) | out-null
    Write-Host -NoNewline "."
    $CreditsUsedEntry | Add-Member -MemberType noteProperty -Name "VMName" -Value $SingleVM.VMName
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[6].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddMinutes(-60).ToUniversalTime().ToString()})
    $CreditsUsedEntry | Add-Member -MemberType NoteProperty -Name "CredUsed_1Hr" -value ([string]$MetricStats.Sum.ToString("0.00"))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[6].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-1).ToUniversalTime().ToString()})
    $CreditsUsedEntry | Add-Member -MemberType NoteProperty -Name "CredUsed_24Hr" -value ([string]$MetricStats.Sum.ToString("0.00"))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[6].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-7).ToUniversalTime().ToString()})
    $CreditsUsedEntry | Add-Member -MemberType NoteProperty -Name "CredUsed_1wk" -value ([string]$MetricStats.Sum.ToString("0.00"))
    $MetricStats = Add_RM_Metrics_Strings ($Metrics[6].data | Where-Object {$_.TimeStamp -ge $TimeNow.AddDays(-30).ToUniversalTime().ToString()})
    $CreditsUsedEntry | Add-Member -MemberType NoteProperty -Name "CredUsed_30d" -value ([string]$MetricStats.Sum.ToString("0.00"))
    $My_CreditsUsed_OutputTable.Add($CreditsUsedEntry) | out-null

}
Write-Host "`n"
Write "`n" | Out-File C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_CPU_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_NetIn_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_NetOut_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_DiskRead_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_DiskWrite_OutputTable | Format-Table -autosize | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_CreditsRem_OutputTable | Format-Table  | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append
$My_CreditsUsed_OutputTable | Format-Table  | Tee-Object -file C:\Temp\$($FileDate)_Azure_Status.txt -append





