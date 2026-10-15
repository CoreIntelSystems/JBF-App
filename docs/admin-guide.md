# Administrator guide

For the Super Administrator, General Secretary and Treasurer who set the
app up and look after it.

## Organisation settings (More > Organisation settings)

Name, short name, member ID prefix, the receipt prefix used on this phone,
and the main and accent colours. Colours change the next time the app
opens. Changing the member ID prefix only affects new members.

The app is a configurable CoreIntel Systems product: zones, contribution
types, welfare case types, expense categories and positions are all data,
not code, so another association can use the same app.

## Users and roles (More > Users and roles)

- Give every officer their own login. Do not share logins: every change is
  recorded in the audit log under the person who made it.
- **Add user:** full name, username, role and a temporary password. Ask
  them to change it under **More > My login and security**.
- **Zone roles** (Zone Mayor, Deputy, Secretary, Treasurer, Organizer,
  Welfare Officer) must be given 1 or 2 zones. They only see members,
  payments, defaulters, welfare cases and charts for those zones.
- To remove access, edit the user and turn off **Can sign in**. Users are
  never deleted so the history stays readable.

Main permissions by role:

| Role | Can |
| --- | --- |
| Super Administrator | Everything |
| Founder | View finance, set dues, audit log, export reports |
| General Secretary | Members, zones, dues, welfare cases and stand-in approval, events, attendance, executives, backups |
| Treasurer | Payments and voids, dues, welfare benefit amounts and payouts, expenses, reports, backups |
| Welfare Chairman | Prepare and approve welfare cases and benefit amounts |
| Zone officers | Their zone's members; zone treasurers record payments; mayors, secretaries and organizers take attendance |
| Auditor | View finance, reports and the audit log |

## Dues and contribution types (More > Contribution types)

Set the **Monthly welfare dues** amount here (Founder, Treasurer or General
Secretary). Arrears are counted from each member's join date. Other types:
silver collection and event contributions (one-off, no arrears), emergency
levy, charity, executive council dues and voluntary donations. Add new
types as needed; old ones can be switched off but not deleted.

## Welfare benefit amounts (More > Welfare > Benefit amounts)

The Treasurer proposes a fixed amount for each type of case. It applies to
new cases only after the Welfare Chairman (or the General Secretary)
approves it.

## Audit log (More > Audit log)

Every sign-in, edit, payment, void, approval, import and settings change,
with who, when and on which phone. It cannot be edited or deleted.

## Cloud sync (More > Cloud sync)

Cloud sync shares one up-to-date record between all officers' phones over
the internet. Every phone still works without internet; it saves changes
and sends them the next time it is online. It syncs when the app opens,
when you come back to it, every 5 minutes while it is open, and when you
tap **Sync now**.

**Start (once, on the main phone).** Open **More > Cloud sync > Sign in
online**, tap *First phone of your organisation? Use a start code*, and
enter the start code from CoreIntel. Leave **Number series** empty. This
phone's records become the organisation's records in the cloud.

**Add a phone.**
1. On the main phone, create a login for the officer in **More > Users
   and roles** (and let it sync).
2. On the officer's phone, install the app and tap **Already set up by
   your group? Sign in online** on the first screen.
3. They enter their username and password (organisation `JBF` is filled
   in). The phone downloads everything and opens the app.

No codes are needed. Five wrong passwords in a row lock that username for
15 minutes.

**Number series.** Each extra phone is given its own series automatically
(`P2`, `P3`...). Numbers made on it include the series, for example
member `JBF-P2-000001`, receipt `RCP-P2-2026-000001`, voucher
`EXP-P2-2026-000001` and welfare case `WEL-P2-2026-0001`, so two phones
never give out the same number.

**When two phones change the same record**, the latest change wins.
Payments and expenses keep their original amount, member and date
whichever phone sends what, and a void can never be undone. Welfare cases
only move forward (pending, approved or rejected, paid). The audit log
from every phone is kept.

**Remove a phone** (lost, or the officer left): **More > Cloud sync >
Phones**, then the bin icon. It stops syncing at once.

**Sync issues.** If a record from another phone cannot be saved (for
example two phones created the same username), Cloud sync shows a
warning. Fix it on the main phone; the corrected record arrives on the
next sync.

With cloud sync on, collections files are no longer needed.

## Field phones

The main phone (usually the Treasurer's or General Secretary's) holds the
full record. To set up a field phone for a zone treasurer:

1. On the main phone make a backup (**More > Backup and restore**).
2. Install the app on the field phone and restore that backup.
3. On the field phone, open **More > Organisation settings** and give it
   its own receipt prefix, for example `Z3`, so its receipt numbers never
   clash with the main phone's.
4. Create the zone treasurer's own login on the main phone *before* making
   the backup, with their zone set.

The field phone sends its collections as a file (see the user guide). On
the main phone, **More > Field phones > Import a collections file** adds
them. Payments already on the main phone are skipped, voids are applied,
and a summary shows anything that could not be imported (for example a
member registered only on the field phone: register them on the main
phone first and import again).

## Backups

See the [backup and restore guide](backup-restore-guide.md). Make a
backup at least once a month and after any big day of collections.
