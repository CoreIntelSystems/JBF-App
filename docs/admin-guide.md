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
