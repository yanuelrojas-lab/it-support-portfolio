<#
.SYNOPSIS
    Reports why a domain user may be unable to log in.

.DESCRIPTION
    "I can't log in" is one of the most common help desk calls, and it has
    several distinct causes that look identical to the user: the account is
    locked, the password expired, the account is disabled, or the account
    expired entirely.

    This script checks all of them at once and reports which apply, so the
    technician can identify the cause in one step instead of clicking through
    ADUC tabs.

.PARAMETER Identity
    The SamAccountName of the user to check.

.PARAMETER Unlock
    Unlocks the account if it is currently locked out. Supports -WhatIf.

.EXAMPLE
    .\Get-UserAccountStatus.ps1 -Identity jdoe

.EXAMPLE
    .\Get-UserAccountStatus.ps1 -Identity jdoe -Unlock

.NOTES
    Requires the ActiveDirectory module (RSAT).
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Identity,

    [switch]$Unlock
)

# Fail early with a clear message rather than a confusing cmdlet error later
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "The ActiveDirectory module is not installed. Install RSAT to continue."
    return
}

Import-Module ActiveDirectory -ErrorAction Stop

try {
    $user = Get-ADUser -Identity $Identity -Properties `
        LockedOut, Enabled, PasswordExpired, PasswordLastSet,
        AccountExpirationDate, LastLogonDate, BadLogonCount, `
        msDS-UserPasswordExpiryTimeComputed -ErrorAction Stop
}
catch {
    Write-Error "Could not find an account matching '$Identity'. Check the username and try again."
    return
}

# Domain policy determines expiry, so read it rather than assuming 90 days
$maxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

$expiryDate = $null
if ($user.'msDS-UserPasswordExpiryTimeComputed') {
    $expiryDate = [datetime]::FromFileTime($user.'msDS-UserPasswordExpiryTimeComputed')
}

Write-Host "`n  Account Status: $($user.Name) ($($user.SamAccountName))" -ForegroundColor Cyan
Write-Host "  $('-' * 55)"

$issues = @()

if (-not $user.Enabled) {
    Write-Host "  Enabled              : NO" -ForegroundColor Red
    $issues += "Account is disabled. Re-enable it or confirm the user is still active."
} else {
    Write-Host "  Enabled              : Yes" -ForegroundColor Green
}

if ($user.LockedOut) {
    Write-Host "  Locked Out           : YES" -ForegroundColor Red
    $issues += "Account is locked out."
} else {
    Write-Host "  Locked Out           : No" -ForegroundColor Green
}

if ($user.PasswordExpired) {
    Write-Host "  Password Expired     : YES" -ForegroundColor Red
    $issues += "Password has expired and must be reset."
} else {
    Write-Host "  Password Expired     : No" -ForegroundColor Green
}

if ($user.AccountExpirationDate -and $user.AccountExpirationDate -lt (Get-Date)) {
    Write-Host "  Account Expired      : YES ($($user.AccountExpirationDate))" -ForegroundColor Red
    $issues += "Account expiration date has passed. Common with contractor accounts."
}

Write-Host "  Password Last Set    : $($user.PasswordLastSet)"
if ($expiryDate) {
    $daysLeft = ($expiryDate - (Get-Date)).Days
    $color = if ($daysLeft -lt 7) { "Yellow" } else { "Gray" }
    Write-Host "  Password Expires     : $expiryDate ($daysLeft days)" -ForegroundColor $color
}
Write-Host "  Last Logon           : $($user.LastLogonDate)"
Write-Host "  Bad Logon Count      : $($user.BadLogonCount)"
Write-Host "  Max Password Age     : $($maxPasswordAge.Days) days"

# A high bad-logon count on an unlocked account usually means a stored
# credential somewhere — a mapped drive, phone mail profile, or service
# still using the old password. Worth flagging so the tech looks for it.
if ($user.BadLogonCount -gt 3 -and -not $user.LockedOut) {
    $issues += "Elevated failed logon count. Check for a cached credential on a phone, mapped drive, or scheduled task."
}

Write-Host "`n  $('-' * 55)"

if ($issues.Count -eq 0) {
    Write-Host "  No blocking issues found on this account." -ForegroundColor Green
    Write-Host "  If the user still cannot log in, check workstation connectivity"
    Write-Host "  to a domain controller and confirm they are using the correct username.`n"
} else {
    Write-Host "  Findings:" -ForegroundColor Yellow
    $issues | ForEach-Object { Write-Host "    - $_" }
    Write-Host ""
}

if ($Unlock -and $user.LockedOut) {
    if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Unlock account")) {
        Unlock-ADAccount -Identity $user.SamAccountName
        Write-Host "  Account unlocked.`n" -ForegroundColor Green
    }
}
elseif ($Unlock -and -not $user.LockedOut) {
    Write-Host "  -Unlock specified, but the account is not locked. No action taken.`n" -ForegroundColor Gray
}
