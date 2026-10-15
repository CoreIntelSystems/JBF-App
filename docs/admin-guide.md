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

## Roles and sign-ins (on each member's page)

Access comes from roles, not from executive positions. Open a member and
use **Roles and access**:

- **Give a role:** the Founder and General Secretary can give any role. A
  Zone Mayor can give zone roles in their own zone. Zone roles need 1 or 2
  zones; zone executives only see those zones.
- **Remove a role** ends its access from now on, on every phone.
- **Reset sign-in** (Founder, General Secretary, or the member's own Zone
  Mayor or Zone Secretary; needs internet) signs the member out everywhere
  so they activate again with their phone number.

- **Helpers:** a Zone Organizer can make any number of members of their
  zone Zone Organizing Helpers, and a Zone Welfare Officer can add Zone
  Welfare Helpers. Helpers are not on the executive council.

## What roles can do (More > Roles)

The Founder can change what any role can do, and add new roles. A Zone
Mayor can add extra zone roles there, but only with access the Mayor has.
Changes reach every phone at the next sync, and people get them the next
time they sign in.

A member with no role only gets their own page. A member with any role
gets the association's records for that role when they sign in. A phone
used by someone with only zone roles holds just their zone(s): those
members and their payments, welfare cases and attendance, plus the shared
lists. When a member joins their zone, or their role changes, the phone
updates itself at the next sync; if all their roles are removed, the
members are taken off the phone.

| Role | Can |
| --- | --- |
| Super Administrator | Everything (CoreIntel support) |
| Founder / President | Everything |
| Director, Patron | View members, finance and reports |
| General Secretary | Members, zones, approve dues amounts, welfare stand-in approval, events, attendance, executives, give roles, reset sign-ins, file complaints |
| Treasurer | Payments and voids, propose dues amounts, welfare benefit amounts and payouts, expenses, reports |
| Organizer | Events and attendance |
| Welfare Chairman | Prepare and approve welfare cases |
| Welfare Secretary | See members, prepare welfare cases |
| Welfare Treasurer | See members, record welfare payouts |
| Zone Mayor | Their zone's members and attendance, give zone roles, add zone roles, reset sign-ins, file complaints |
| Zone Secretary | Their zone's members and attendance, reset sign-ins, file complaints |
| Other zone executives | Their zone's members; zone treasurers record payments; zone organizers and welfare officers add helpers |
| Zone helpers | Their zone's members; organizing helpers take attendance |
| Disciplinary Committee | See members, handle complaints |
| Auditor | View finance, reports and the audit log |
| Electoral Commission | See members |

## Importing the member list (Members > upload icon)

Use this once, on the main phone, to register many people from an Excel
(.xlsx) or CSV list. The first row needs headings: Name, Phone 1, Phone 2,
Phone 3, and optionally Zone and Zone 2 (zone numbers 1 to 8).

- Names ending "King June" or "Queen June" are tidied and set the gender.
- Rows with no name, no usable phone, or a number already registered are
  left out. You can share the list of left-out rows afterwards.
- People without a zone in the file all go into the zone you choose on the
  screen, or are left out.
- Imported members may check and correct their own name, contact details
  and zone (Me > Edit my details and zones). Members you register later are
  updated by the Founder, General Secretary or the member's Zone Secretary
  or Mayor.

## Old username logins (More > Old username logins)

Older username logins are kept for phones set up before member sign-in.
Link each one to its member record. To remove access, turn off **Can sign
in**. New executives do not need a username: give them a role instead.

## Dues and contribution types (More > Contribution types)

Set the **Monthly welfare dues** amount here. The Founder can change it
directly. When the Treasurer changes it, the new amount waits until the
Founder or General Secretary approves it. Dues stop while a member is
suspended. Arrears are counted from each member's join date. Other types:
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
