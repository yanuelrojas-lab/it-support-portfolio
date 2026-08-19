# SOP-03: New Hire Workstation Setup

| | |
|---|---|
| **Document ID** | SOP-03 |
| **Audience** | Help Desk Technician |
| **Estimated Time** | 45–90 minutes |
| **Version** | 1.0 |

---

## 1. Purpose

To prepare, configure, and deliver a workstation for a new employee so that the
machine, the domain account, and the required access are all in place before
the employee's first day.

## 2. Scope

Covers standard Windows workstations joined to the domain. Specialized
hardware, elevated-privilege roles, and non-standard software require
additional approval outside this procedure.

## 3. Prerequisites

- Completed onboarding request with start date, job title, department, and
  manager
- Available workstation matching the department's hardware standard
- Delegated permission to create accounts in the appropriate Organizational Unit
- Access to the imaging system and software deployment tools

---

## 4. Timeline

Starting the day before is not realistic. Account replication, software
deployment, and license provisioning all take time, and a new hire sitting
without a working machine on day one is a poor first impression of the whole
organization.

| When | Task |
|---|---|
| 5 days before | Confirm request details; reserve hardware |
| 3 days before | Image the workstation; create the domain account |
| 2 days before | Install software; configure access and mailbox |
| 1 day before | Final verification; stage at the desk |
| Day one | Deliver, walk through login, confirm access |

---

## 5. Procedure

### Step 1 — Verify the Request

Confirm the start date, department, job title, and reporting manager. Confirm
which access groups the role requires — copy these from the role definition, not
from another employee's account. Copying an existing user's permissions
propagates whatever excess access that user accumulated, which is how privilege
creep spreads through an organization.

### Step 2 — Prepare the Hardware

Inspect the machine for physical damage. Confirm it meets the department
standard for the role. Record the asset tag, serial number, and assigned user in
the inventory system before deployment — assets not recorded at deployment are
rarely recorded at all.

### Step 3 — Image the Workstation

Deploy the current standard image. After imaging:

- Apply all pending Windows updates and reboot as required
- Confirm the device name follows the naming convention
- Join the machine to the domain and confirm it appears in the correct OU
- Verify the endpoint protection agent is installed, running, and reporting in
- Confirm disk encryption is enabled and the recovery key is escrowed

### Step 4 — Create the Domain Account

```powershell
New-ADUser `
    -Name "Jane Doe" `
    -GivenName "Jane" `
    -Surname "Doe" `
    -SamAccountName "jdoe" `
    -UserPrincipalName "jdoe@company.local" `
    -Path "OU=Accounting,OU=Users,DC=company,DC=local" `
    -Title "Staff Accountant" `
    -Department "Accounting" `
    -AccountPassword (Read-Host -AsSecureString "Temporary password") `
    -ChangePasswordAtLogon $true `
    -Enabled $true

# Add role-based group memberships
Add-ADGroupMember -Identity "Accounting-Users" -Members "jdoe"
Add-ADGroupMember -Identity "VPN-Users" -Members "jdoe"
```

Assign access through group membership rather than direct permissions. Group
membership is visible, auditable, and simple to revoke on the day the employee
leaves; direct permissions are none of those things.

### Step 5 — Install and Configure Software

Install the standard software set, plus any department-specific applications
identified in the request. Configure the email profile, map required network
drives via Group Policy, and add department printers.

Confirm each licensed application is properly provisioned rather than running
in trial mode — an application that stops working after 30 days becomes a ticket
you will have to solve anyway.

### Step 6 — Verify Before Delivery

Log in with the new account on the actual workstation. Do not skip this and
assume it works.

- [ ] Domain login succeeds
- [ ] Email opens and can send and receive
- [ ] Network drives are mapped and accessible
- [ ] Default printer prints a test page
- [ ] All required applications launch
- [ ] Internet access works
- [ ] VPN connects, if the role requires it
- [ ] The user is prompted to change the temporary password

### Step 7 — Deliver to the User

Walk the new hire through first login and the password change. Show them how to
access email, network drives, and printing. Provide the help desk contact
method and explain how to submit a ticket.

Keep this brief and welcoming. A new employee on day one is absorbing a great
deal at once, so cover what they need to start working and let them know where
to find help for the rest.

---

## 6. Documentation and Handoff

Record the asset tag and assigned user in inventory, note the account name and
group memberships in the ticket, and confirm the manager has been notified that
setup is complete. Close the ticket only after the user has successfully logged
in.

## 7. Related Procedures

- SOP-01: Active Directory Password Reset
- SOP-02: Printer Troubleshooting

---

## Revision History

| Version | Date | Change |
|---|---|---|
| 1.0 | — | Initial version |
