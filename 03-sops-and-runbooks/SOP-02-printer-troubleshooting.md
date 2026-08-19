# SOP-02: Printer Troubleshooting

| | |
|---|---|
| **Document ID** | SOP-02 |
| **Audience** | Help Desk Technician (Tier 1) |
| **Estimated Time** | 10–30 minutes |
| **Version** | 1.0 |

---

## 1. Purpose

To diagnose and resolve network and local printing failures using a structured
process that isolates the fault to the document, the driver, the queue, the
workstation, the network, or the hardware — rather than guessing.

## 2. Why Structure Matters Here

"The printer isn't working" describes a dozen different failures with different
causes. The single most common mistake is jumping to reinstalling the driver
before establishing whether the problem affects one user or all users. That one
question eliminates half the possible causes in about ten seconds.

---

## 3. Initial Triage — Ask Before Touching Anything

| Question | What the answer tells you |
|---|---|
| Is it one user or everyone? | One user → workstation or driver. Everyone → printer, queue, or network. |
| One application or all applications? | One app → application settings. All → driver or system. |
| One document or all documents? | One document → file corruption or unusual formatting. |
| When did it last work? | Points to a change: update, move, cable, or config. |
| What exactly happens? | Nothing printing, error message, blank pages, and garbled output are four different faults. |

Record the answers in the ticket before proceeding.

---

## 4. Procedure

### Step 1 — Physical Check

Confirm the obvious before spending time on software. Check that the printer is
powered on and shows a ready state, has paper in the correct tray, has toner or
ink remaining, has no open panels, and shows no jam or error on its display.
Verify the network cable is seated at both ends, or that Wi-Fi shows connected.

A surprising share of printer tickets end here. Check it anyway — and check it
without making the user feel foolish for not checking themselves.

### Step 2 — Print a Test Page from the Printer Itself

Use the printer's own control panel to print a configuration or test page.

- **Prints successfully** → hardware and print engine are fine. The fault is in
  the network path, driver, or queue. Continue to Step 3.
- **Fails to print** → hardware fault. Skip to Step 7.

This step is worth doing early because it cleanly splits the problem in half.

### Step 3 — Check the Print Queue

1. Open **Settings → Bluetooth & devices → Printers & scanners**.
2. Select the printer and choose **Open print queue**.
3. Look for stuck jobs, especially one in an error state at the top blocking
   everything behind it.
4. Cancel all documents. If a job will not clear, restart the spooler:

```powershell
# Stop the spooler, clear the queue, and restart
Stop-Service -Name Spooler -Force
Remove-Item -Path "$env:SystemRoot\System32\spool\PRINTERS\*" -Force
Start-Service -Name Spooler
```

5. Confirm the printer is not set to **Pause Printing** or **Use Printer Offline**.

### Step 4 — Verify Network Connectivity

For network printers, confirm the workstation can reach the printer:

```
ping 192.168.1.50
```

- **Replies** → the network path is fine; the issue is driver or queue.
- **Times out** → verify the printer's IP has not changed. Printers assigned
  addresses by DHCP frequently move after a reboot, which breaks every
  workstation configured against the old address. This is one of the most
  common causes of an "everyone suddenly can't print" ticket. A static
  reservation prevents recurrence.

### Step 5 — Verify Default Printer and Port

Confirm the correct printer is set as default — users often print to a device
in another department without realizing it. Then check **Printer Properties →
Ports** and confirm the port matches the printer's current IP address.

### Step 6 — Reinstall the Driver

Only reach this step after the above have been ruled out.

1. Remove the printer from **Printers & scanners**.
2. Open **Print Management** (`printmanagement.msc`) → **All Drivers**, and
   remove the driver package.
3. Restart the spooler.
4. Re-add the printer, using the manufacturer's current driver rather than a
   generic one where possible.
5. Print a test page from the workstation.

### Step 7 — Hardware Faults

If the printer cannot print its own test page, the fault is mechanical or
internal. Clear any jam following the on-screen guidance, reseat the toner or
ink cartridge, and power cycle the printer with a full 30-second power-off.

If the fault persists, document the error code shown on the display and
escalate for service. Do not attempt internal repairs on leased or
under-warranty equipment — this can void coverage.

---

## 5. Escalation Criteria

Escalate when: a hardware fault requires a service call, the printer is under a
managed print contract, the issue affects a print server rather than a single
device, or the fault recurs after a successful fix — recurrence usually means
the root cause was not addressed.

## 6. Documentation

Record the triage answers, the step that resolved the issue, and any
configuration changed. If the cause was a DHCP address change, note the
recommendation for a static reservation so the pattern is visible if it
recurs elsewhere.

---

## Revision History

| Version | Date | Change |
|---|---|---|
| 1.0 | — | Initial version |
