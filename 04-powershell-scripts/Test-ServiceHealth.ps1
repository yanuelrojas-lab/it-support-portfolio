<#
.SYNOPSIS
    Checks whether critical Windows services are running, and optionally
    restarts any that have stopped.

.DESCRIPTION
    A stopped service produces symptoms that look like something else entirely.
    The Print Spooler stopping becomes "nobody can print." The Workstation
    service stopping becomes "my mapped drives disappeared." Checking services
    early saves time chasing the wrong cause.

    Services set to start automatically but currently stopped are the ones that
    matter — a stopped service that is set to Manual is usually fine.

.PARAMETER ComputerName
    Target computer. Defaults to the local machine.

.PARAMETER ServiceName
    Services to check. Defaults to a common support-relevant set.

.PARAMETER Restart
    Attempts to start any stopped service. Supports -WhatIf.

.EXAMPLE
    .\Test-ServiceHealth.ps1

.EXAMPLE
    .\Test-ServiceHealth.ps1 -ComputerName PC-042 -Restart

.EXAMPLE
    .\Test-ServiceHealth.ps1 -ServiceName Spooler, W32Time -Restart -WhatIf

.NOTES
    Remote checks require WinRM and administrative rights on the target.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ComputerName = $env:COMPUTERNAME,

    [string[]]$ServiceName = @(
        'Spooler',      # Print Spooler - printing
        'Dhcp',         # DHCP Client - address assignment
        'Dnscache',     # DNS Client - name resolution
        'LanmanWorkstation', # Workstation - mapped drives and shares
        'BITS',         # Background Intelligent Transfer - updates
        'wuauserv',     # Windows Update
        'WinDefend',    # Microsoft Defender
        'W32Time'       # Windows Time - Kerberos depends on clock accuracy
    ),

    [switch]$Restart
)

# Passing -ComputerName forces a remote connection even when the target is the
# local host, so detect that case and query locally instead.
$isLocal = ($ComputerName -eq $env:COMPUTERNAME) -or
           ($ComputerName -eq 'localhost') -or
           ($ComputerName -eq '.')

if (-not $isLocal) {
    if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
        Write-Error "$ComputerName is unreachable."
        return
    }
}

$svcParams = @{ ErrorAction = 'Stop' }
$cimParams = @{ ErrorAction = 'SilentlyContinue' }
if (-not $isLocal) {
    $svcParams['ComputerName'] = $ComputerName
    $cimParams['ComputerName'] = $ComputerName
}

Write-Host "`n  Service health: $ComputerName" -ForegroundColor Cyan
Write-Host "  $('-' * 62)"

$stopped = @()

foreach ($name in $ServiceName) {
    try {
        $service = Get-Service -Name $name @svcParams

        # StartType is not exposed on the Get-Service object when querying
        # remotely, so pull it from CIM instead
        $startType = (Get-CimInstance -ClassName Win32_Service `
                        -Filter "Name='$name'" @cimParams).StartMode

        $label = "{0,-22} {1,-12} {2}" -f $service.DisplayName.Substring(0, [Math]::Min(22, $service.DisplayName.Length)),
                                          $service.Status,
                                          $startType

        if ($service.Status -eq 'Running') {
            Write-Host "  $label" -ForegroundColor Green
        }
        elseif ($startType -eq 'Auto') {
            # Set to start automatically but not running — this is the real problem case
            Write-Host "  $label  <-- should be running" -ForegroundColor Red
            $stopped += $service
        }
        else {
            Write-Host "  $label" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host ("  {0,-22} not found on this system" -f $name) -ForegroundColor DarkGray
    }
}

Write-Host "  $('-' * 62)"

if ($stopped.Count -eq 0) {
    Write-Host "  All automatic services are running.`n" -ForegroundColor Green
    return
}

Write-Host "  $($stopped.Count) automatic service(s) stopped.`n" -ForegroundColor Yellow

if (-not $Restart) {
    Write-Host "  Re-run with -Restart to start them.`n" -ForegroundColor Gray
    return
}

foreach ($service in $stopped) {
    if ($PSCmdlet.ShouldProcess("$($service.Name) on $ComputerName", "Start service")) {
        try {
            Start-Service -InputObject $service -ErrorAction Stop
            Start-Sleep -Seconds 2
            $service.Refresh()

            if ($service.Status -eq 'Running') {
                Write-Host "  Started: $($service.DisplayName)" -ForegroundColor Green
            } else {
                Write-Host "  $($service.DisplayName) did not stay running." -ForegroundColor Red
            }
        }
        catch {
            Write-Host "  Failed to start $($service.DisplayName): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# A service that stops repeatedly has an underlying cause. Restarting it
# closes the ticket without fixing the problem, and it will be back.
Write-Host "`n  If a service stops again after restarting, check the System event"
Write-Host "  log for the cause rather than restarting it a second time.`n" -ForegroundColor Gray
