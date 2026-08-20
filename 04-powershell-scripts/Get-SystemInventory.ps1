<#
.SYNOPSIS
    Collects hardware and OS details from one or more computers.

.DESCRIPTION
    Gathers the information usually needed for asset tracking, warranty
    lookups, and refresh planning: make and model, serial number, CPU, memory,
    disk, OS build, and uptime.

    Written to survive a machine being offline -- unreachable hosts are recorded
    and reported rather than stopping the run, which matters when scanning a
    list of a hundred workstations overnight.

.PARAMETER ComputerName
    One or more computer names. Defaults to the local machine.

.PARAMETER ExportPath
    Optional CSV output path.

.EXAMPLE
    .\Get-SystemInventory.ps1

.EXAMPLE
    .\Get-SystemInventory.ps1 -ComputerName PC-001, PC-002 -ExportPath .\inventory.csv

.EXAMPLE
    Get-Content .\computers.txt | .\Get-SystemInventory.ps1 -ExportPath .\inventory.csv

.NOTES
    Remote queries require WinRM enabled and administrative rights on the target.
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline = $true, Position = 0)]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [string]$ExportPath
)

begin {
    $results     = @()
    $unreachable = @()
}

process {
    foreach ($computer in $ComputerName) {

        # Determine whether this is the local machine. Passing -ComputerName to
        # Get-CimInstance forces a WinRM connection even when the target is the
        # local host, which fails unless remoting is enabled. Querying locally
        # needs no -ComputerName at all.
        $isLocal = ($computer -eq $env:COMPUTERNAME) -or
                   ($computer -eq 'localhost') -or
                   ($computer -eq '.')

        if (-not $isLocal) {
            if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet)) {
                Write-Warning "$computer is unreachable. Skipping."
                $unreachable += $computer
                continue
            }
        }

        # Build the parameter set once; omit -ComputerName entirely when local
        $cimParams = @{ ErrorAction = 'Stop' }
        if (-not $isLocal) { $cimParams['ComputerName'] = $computer }

        try {
            $cs   = Get-CimInstance -ClassName Win32_ComputerSystem  @cimParams
            $os   = Get-CimInstance -ClassName Win32_OperatingSystem @cimParams
            $bios = Get-CimInstance -ClassName Win32_BIOS            @cimParams
            $cpu  = Get-CimInstance -ClassName Win32_Processor       @cimParams |
                        Select-Object -First 1
            $disk = Get-CimInstance -ClassName Win32_LogicalDisk     @cimParams |
                        Where-Object { $_.DeviceID -eq 'C:' }

            $results += [PSCustomObject]@{
                ComputerName   = $computer
                Manufacturer   = $cs.Manufacturer
                Model          = $cs.Model
                SerialNumber   = $bios.SerialNumber
                CPU            = $cpu.Name.Trim()
                Cores          = $cpu.NumberOfCores
                MemoryGB       = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
                OS             = $os.Caption
                Build          = $os.BuildNumber
                Architecture   = $os.OSArchitecture
                DiskTotalGB    = if ($disk) { [math]::Round($disk.Size / 1GB, 1) } else { $null }
                DiskFreeGB     = if ($disk) { [math]::Round($disk.FreeSpace / 1GB, 1) } else { $null }
                DiskFreePct    = if ($disk -and $disk.Size -gt 0) {
                                     [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
                                 } else { $null }
                LastBoot       = $os.LastBootUpTime
                UptimeDays     = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 1)
                LoggedOnUser   = $cs.UserName
                CollectedOn    = Get-Date -Format 'yyyy-MM-dd HH:mm'
            }

            Write-Host "  Collected: $computer" -ForegroundColor Green
        }
        catch {
            Write-Warning "$computer - query failed: $($_.Exception.Message)"
            $unreachable += $computer
        }
    }
}

end {
    if ($results.Count -eq 0) {
        Write-Host "`n  No data collected.`n" -ForegroundColor Yellow
        return
    }

    $results | Format-Table ComputerName, Model, MemoryGB, OS, DiskFreePct, UptimeDays -AutoSize

    # Two things worth flagging to a technician without being asked:
    # low disk almost always precedes a support call, and a machine that has
    # not rebooted in a month is usually missing patches.
    $lowDisk = $results | Where-Object { $_.DiskFreePct -ne $null -and $_.DiskFreePct -lt 15 }
    if ($lowDisk) {
        Write-Host "  Low disk space (under 15% free):" -ForegroundColor Yellow
        $lowDisk | ForEach-Object { Write-Host "    - $($_.ComputerName): $($_.DiskFreePct)% free" }
        Write-Host ""
    }

    $staleBoot = $results | Where-Object { $_.UptimeDays -gt 30 }
    if ($staleBoot) {
        Write-Host "  Not rebooted in over 30 days (may be missing patches):" -ForegroundColor Yellow
        $staleBoot | ForEach-Object { Write-Host "    - $($_.ComputerName): $($_.UptimeDays) days" }
        Write-Host ""
    }

    if ($unreachable.Count -gt 0) {
        Write-Host "  Unreachable: $($unreachable -join ', ')" -ForegroundColor Red
        Write-Host ""
    }

    if ($ExportPath) {
        $results | Export-Csv -Path $ExportPath -NoTypeInformation
        Write-Host "  Exported $($results.Count) records to $ExportPath`n" -ForegroundColor Cyan
    }
}
