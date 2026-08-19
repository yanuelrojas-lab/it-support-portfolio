# SOP-01: Active Directory Password Reset

| | |
|---|---|
| **Document ID** | SOP-01 |
| **Audience** | Help Desk Technician (Tier 1) |
| **Estimated Time** | 5 minutes |
| **Version** | 1.0 |

---

## 1. Purpose

To reset a user's Active Directory domain password following a lockout,
forgotten password, or suspected credential compromise, while verifying the
requester's identity before making any change.

## 2. Scope

Applies to standard domain user accounts. **Does not apply to** service
accounts, administrative accounts, or any account flagged as privileged —
those require escalation under Section 7.

## 3. Prerequisites

- Delegated permission to reset passwords in the target Organizational Unit
- Access to Active Directory Users and Computers (ADUC) or the AD PowerShell module
- Access to the ticketing system to record the request
- An approved identity verification method

---

## 4. Identity Verification — Required Before Any Reset

**Do not skip this step.** Password reset requests are one of the most common
social engineering vectors. An attacker who can convince a technician to reset
a password gains everything that account can reach.

Verify the caller using **at least two** of the following:

1. Employee ID number
2. A challenge question on file
3. Manager confirmation via a separately initiated call
4. Callback to the phone number on record — not a number the caller supplies

**Stop and escalate if:** the caller pressures you to skip verification, claims
unusual urgency from an executive, cannot answer basic questions about their
role, or requests the password be sent to an external address.

---

## 5. Procedure

### Using Active Directory Users and Computers

1. Open **Active Directory Users and Computers** (`dsa.msc`).
2. Right-click the domain and select **Find**. Search for the user by full name
   or username.
3. Right-click the account and select **Reset Password**.
4. Enter a strong temporary password meeting the domain policy.
5. Check **User must change password at next logon**. This is required —
   the technician should never end up knowing a password the user keeps using.
6. If the account shows as locked out, open **Properties → Account** and check
   **Unlock account**. A reset alone does not clear an existing lockout.
7. Click **OK**.

### Using PowerShell

```powershell
# Reset the password and force a change at next logon
Set-ADAccountPassword -Identity "jdoe" -Reset `
    -NewPassword (Read-Host -AsSecureString "New password")

Set-ADUser -Identity "jdoe" -ChangePasswordAtLogon $true

# Clear the lockout if one is present
Unlock-ADAccount -Identity "jdoe"

# Confirm the result
Get-ADUser -Identity "jdoe" -Properties LockedOut, PasswordLastSet |
    Select-Object Name, LockedOut, PasswordLastSet
```

---

## 6. Delivering the Password and Verifying

Provide the temporary password through a channel separate from the one used to
request it — a phone call to the number on record, or a message to the user's
manager. Never send it in the same email thread that requested the reset.

Confirm with the user that they can log in and that the change-password prompt
appeared. Do not close the ticket until the user confirms access.

**If the user still cannot log in**, check in this order:
- Caps Lock, and whether the user is typing the password correctly
- Whether the account is still locked (a second lockout can occur immediately)
- Whether the account is disabled or expired
- Whether the workstation has network connectivity to a domain controller
- Whether replication delay is a factor in a multi-DC environment — allow
  15 minutes or force replication

---

## 7. Escalation Criteria

Escalate to Tier 2 or the security team when:

- Identity verification cannot be completed satisfactorily
- The account is administrative, privileged, or a service account
- The account has locked out repeatedly, which may indicate a stored
  credential on another device or an active brute-force attempt
- There is any indication of compromise — unexpected password change, login
  attempts from unfamiliar locations, or a user reporting they did not request
  the reset

## 8. Documentation

Record in the ticket: the verification method used, the time of the reset,
confirmation that the change-at-next-logon flag was set, and the user's
confirmation of access. **Never record the password itself in the ticket.**

---

## Revision History

| Version | Date | Change |
|---|---|---|
| 1.0 | — | Initial version |
