$rootPath = 'C:/Ruta/del/Script'; ### <<<<<<<<<<<<<< IMPORTANT
$listSRVs = Get-Content -Path "$rootPath\servers.txt";
$nameProcess = "services"; ### <<<<<<<<<<<<<< IMPORTANT


$pathCSV = "$rootPath\output.csv";

New-Item -Path $pathCSV -ItemType File -Force -Value "Fecha,Hostname,PID,Name,Version,A_CPU(%),A_RAM(MB),SO_CPU(%),SO_RAM(TotalGB),SO_RAM(TotalUsadoGB),SO_RAM(%) `n";

$creds = Get-Credential;

foreach($srv in $listSRVs)
{

    $session = New-PSSession -ComputerName $srv -Credential $creds;
        
    try
    {
        $process = Invoke-Command -Session $session -ScriptBlock {
            param($nameProcess);Get-Process -Name $nameProcess;
        } -ErrorAction Stop -ArgumentList $nameProcess;
        
        $agentID = $process.Id;
        $agentName = $process.Name;
        $agentVersion = $process.ProductVersion;

        $agent = Invoke-Command -Session $session -ScriptBlock {
            param($process);Get-WmiObject -Query "SELECT WorkingSetPrivate, PercentProcessorTime FROM Win32_PerfFormattedData_PerfProc_Process WHERE IDProcess = $($process.Id) ";
        } -ArgumentList $process;

        $agentRAM = [math]::round($agent.WorkingSetPrivate / 1MB, 2);
        $agentCPU = $agent.PercentProcessorTime;

        $osRAM = Invoke-Command -Session $session -ScriptBlock {
            Get-WmiObject -Class Win32_OperatingSystem;
        };

        $osTotalRAM = [math]::round($osRAM.TotalVisibleMemorySize / 1MB, 2);
        $osFreeRAM = [math]::round($osRAM.FreePhysicalMemory / 1MB, 2);
        $osUsedRAM = $osTotalRAM - $osFreeRAM;
        $osRAMUsagePercent = [math]::round(($osUsedRAM / $osTotalRAM) * 100, 2);

        $osCPU = Invoke-Command -Session $session -ScriptBlock {
            Get-WmiObject -Query "SELECT PercentProcessorTime FROM Win32_PerfFormattedData_PerfOS_Processor WHERE Name='_Total'";
        };

        $osCPUUsagePercent  = [math]::round($osCPU.PercentProcessorTime, 2);
        
        Add-Content -Path $pathCSV -Value "$(Get-Date -Format "yyyy-MM-dd HH:mm"),$srv,$agentID,$agentName,$agentVersion,$agentCPU,$agentRAM,$osCPUUsagePercent,$osTotalRAM,$osUsedRAM,$osRAMUsagePercent";

        Write-Output ">>>>>> $SRV <<< >>> OK <<<<<<";
    }
    catch
    {
        Add-Content -Path $pathCSV -Value "$(Get-Date -Format "yyyy-MM-dd HH:mm"),$srv,,,,,,,,,";
        Write-Output ">>>>>> $SRV <<< >>> BAD <<<<<<";
    }
    finally
    {
        Remove-PSSession $session
    }
   
}
