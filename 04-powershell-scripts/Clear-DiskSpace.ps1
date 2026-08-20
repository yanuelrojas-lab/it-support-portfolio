<#
.SYNOPSIS
    Reclaims disk space on a workstation by clearing safe temporary locations.

.DESCRIPTION
    "My computer is full" and "everything is slow" are frequently the same
    ticket. This script clears the locations that are safe to empty -- Windows
    temp, user temp, Windows Update cache, and per-user browser caches --
    reporting how much each one recovered.

    Only well-understood temporary paths are touched. Nothing here removes user
    documents, profiles, or installed software.

.PARAMETER IncludeBrowserCache
    Also clears Chrome and Edge caches. Off by default because it signs users
    out of some sites, which generates its own ticket if unexpected.

.PARAMETER MinimumFreeGB
    Reports a warning if free space is still below this threshold afterward.

.EXAMPLE
    .\Clear-DiskSpace.ps1 -WhatIf

.EXAMPLE
    .\Clear-DiskSpace.ps1 -IncludeBrowserCache

.NOTES
    Run as Administrator for the system-level paths. Always run -WhatIf first
    on a machine you do not own.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$IncludeBrowserCache,

    [double]$MinimumFreeGB = 10
)

function Get-FreeSpaceGB {
    $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
    return [math]::Round($drive.FreeSpace / 1GB, 2)
}

function Clear-PathSafely {
    param(
        [string]$Path,
        [string]$Label
    )

    if (-not (Test-Path $Path)) {
        Write-Host "  Skipped : $Label (not present)" -ForegroundColor Gray
        return 0
    }

    # Measure before deleting so we can report what was actually recovered
    $before = 0
    try {
        $before = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                   Measure-Object -Property Length -Sum).Sum
    }
    catch { }

    if (-not $before) { $before = 0 }

    if ($PSCmdlet.ShouldProcess($Path, "Clear contents")) {
        # Files locked by running processes will fail; that is expected and
        # not worth surfacing as an error to the technician.
        Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

        $after = 0
        try {
            $after = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                      Measure-Object -Property Length -Sum).Sum
        }
        catch { }
        if (-not $after) { $after = 0 }

        $recovered = [math]::Round(($before - $after) / 1MB, 1)
        Write-Host "  Cleared : $Label ($recovered MB)" -ForegroundColor Green
        return $recovered
    }
    else {
        Write-Host "  Would clear: $Label ($([math]::Round($before / 1MB, 1)) MB)" -ForegroundColor Cyan
        return 0
    }
}

$startFree = Get-FreeSpaceGB
Write-Host "`n  Free space before: $startFree GB" -ForegroundColor Cyan
Write-Host "  $('-' * 55)"

$totalMB = 0

$totalMB += Clear-PathSafely -Path "$env:WINDIR\Temp"            -Label "Windows temp"
$totalMB += Clear-PathSafely -Path "$env:TEMP"                   -Label "User temp"
$totalMB += Clear-PathSafely -Path "$env:WINDIR\Prefetch"        -Label "Prefetch"
$totalMB += Clear-PathSafely -Path "$env:WINDIR\SoftwareDistribution\Download" -Label "Windows Update cache"

if ($IncludeBrowserCache) {
    $totalMB += Clear-PathSafely `
        -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" -Label "Chrome cache"
    $totalMB += Clear-PathSafely `
        -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" -Label "Edge cache"
}

# Recycle Bin is separate because it has its own cmdlet and is worth calling out
if ($PSCmdlet.ShouldProcess("Recycle Bin", "Empty")) {
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Host "  Cleared : Recycle Bin" -ForegroundColor Green
    }
    catch {
        Write-Host "  Skipped : Recycle Bin (already empty or inaccessible)" -ForegroundColor Gray
    }
}

Write-Host "  $('-' * 55)"

$endFree   = Get-FreeSpaceGB
$recovered = [math]::Round($endFree - $startFree, 2)

Write-Host "  Free space after : $endFree GB"
Write-Host "  Recovered        : $recovered GB" -ForegroundColor Green

if ($endFree -lt $MinimumFreeGB) {
    Write-Host "`n  Still below the $MinimumFreeGB GB threshold." -ForegroundColor Yellow
    Write-Host "  Next steps to investigate:"
    Write-Host "    - Large files in the user profile (Downloads, Desktop, Videos)"
    Write-Host "    - Old Windows installation (Windows.old) from a feature update"
    Write-Host "    - Local OneDrive files not set to online-only"
    Write-Host "    - Shadow copies and System Restore allocation`n"
} else {
    Write-Host ""
}
