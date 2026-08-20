<#
.SYNOPSIS
    Creates Active Directory user accounts in bulk from a CSV file.

.DESCRIPTION
    Onboarding several people at once -- a new class of hires, a seasonal
    intake -- is slow and error-prone through the GUI. This script reads a CSV,
    validates each row before touching the directory, creates the accounts, and
    reports what succeeded and what did not.

    Validation runs first so a malformed row does not leave half the batch
    created and half not.

.PARAMETER CsvPath
    Path to the input CSV. Required columns: FirstName, LastName, Username,
    Title, Department, OU. Optional: Manager.

.PARAMETER DefaultPassword
    Temporary password applied to every account. All accounts are flagged to
    require a change at first logon.

.PARAMETER ValidateOnly
    Runs validation and reports results without creating anything. Worth doing
    on any batch you did not build yourself.

.EXAMPLE
    .\New-BulkADUser.ps1 -CsvPath .\sample-newusers.csv -ValidateOnly

.EXAMPLE
    .\New-BulkADUser.ps1 -CsvPath .\newhires.csv

.NOTES
    Requires the ActiveDirectory module and permission to create users in the
    target OUs.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [string]$DefaultPassword,

    [switch]$ValidateOnly
)

if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "The ActiveDirectory module is not installed. Install RSAT to continue."
    return
}
Import-Module ActiveDirectory -ErrorAction Stop

$users = Import-Csv -Path $CsvPath
Write-Host "`n  Loaded $($users.Count) rows from $CsvPath`n" -ForegroundColor Cyan

# ----- Validation pass -------------------------------------------------------
# Check everything before creating anything, so a bad row does not leave the
# batch half-applied.

$required = @('FirstName', 'LastName', 'Username', 'Title', 'Department', 'OU')
$problems = @()
$row = 0

foreach ($user in $users) {
    $row++
    $label = "Row $row"

    foreach ($field in $required) {
        if ([string]::IsNullOrWhiteSpace($user.$field)) {
            $problems += "$label - missing required field '$field'"
        }
    }

    if ($user.Username) {
        $label = "Row $row ($($user.Username))"

        if (Get-ADUser -Filter "SamAccountName -eq '$($user.Username)'" -ErrorAction SilentlyContinue) {
            $problems += "$label - username already exists in the directory"
        }
        # SamAccountName has a hard 20-character limit; longer values fail at creation
        if ($user.Username.Length -gt 20) {
            $problems += "$label - username exceeds the 20-character SamAccountName limit"
        }
    }

    if ($user.OU) {
        try {
            Get-ADOrganizationalUnit -Identity $user.OU -ErrorAction Stop | Out-Null
        }
        catch {
            $problems += "$label - target OU not found: $($user.OU)"
        }
    }
}

if ($problems.Count -gt 0) {
    Write-Host "  Validation found $($problems.Count) problem(s):" -ForegroundColor Red
    $problems | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    Write-Host "`n  No accounts were created. Correct the CSV and run again.`n"
    return
}

Write-Host "  Validation passed. All rows look good.`n" -ForegroundColor Green

if ($ValidateOnly) {
    Write-Host "  -ValidateOnly specified. Stopping here without creating accounts.`n" -ForegroundColor Gray
    return
}

# ----- Creation pass ---------------------------------------------------------

if (-not $DefaultPassword) {
    $securePassword = Read-Host -AsSecureString "  Enter the temporary password for these accounts"
} else {
    $securePassword = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
}

$created = 0
$failed  = @()

foreach ($user in $users) {
    $displayName = "$($user.FirstName) $($user.LastName)"
    $domain      = (Get-ADDomain).DNSRoot

    if ($PSCmdlet.ShouldProcess($user.Username, "Create AD user")) {
        try {
            New-ADUser `
                -Name                  $displayName `
                -GivenName             $user.FirstName `
                -Surname               $user.LastName `
                -SamAccountName        $user.Username `
                -UserPrincipalName     "$($user.Username)@$domain" `
                -DisplayName           $displayName `
                -Title                 $user.Title `
                -Department            $user.Department `
                -Path                  $user.OU `
                -AccountPassword       $securePassword `
                -ChangePasswordAtLogon $true `
                -Enabled               $true `
                -ErrorAction Stop

            # Manager is optional; a bad value should not fail the whole account
            if ($user.Manager) {
                try {
                    Set-ADUser -Identity $user.Username -Manager $user.Manager -ErrorAction Stop
                }
                catch {
                    Write-Warning "  $($user.Username): account created, but manager '$($user.Manager)' could not be set."
                }
            }

            Write-Host "  Created: $displayName ($($user.Username))" -ForegroundColor Green
            $created++
        }
        catch {
            Write-Host "  FAILED : $displayName - $($_.Exception.Message)" -ForegroundColor Red
            $failed += $user.Username
        }
    }
}

Write-Host "`n  $('-' * 55)"
Write-Host "  Created: $created of $($users.Count)"
if ($failed.Count -gt 0) {
    Write-Host "  Failed : $($failed -join ', ')" -ForegroundColor Red
}
Write-Host "  Group membership is not assigned here -- apply role-based groups separately.`n"
