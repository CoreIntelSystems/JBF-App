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
| Disciplinary Committee (Chairperson, Secretary, member) | See members, handle complaints; Chairperson and Secretary lead the committee office |
| Auditor | View finance, reports and the audit log |
| Electoral Commission | See members |

## Importing the member list (Members > upload icon)

Use this once, on the main phone, to register many people from an Excel
(.xlsx) or CSV list. The first row needs headings: Name, Phone 1, Phone 2,
Phone 3, and optionally Zone and Zone 2 (zone numbers 1 to 8).

- Names ending "King June" or "Queen June" are tidied and set the gender.
- Rows with no name, no usable phone, or a number already registered are
  left out. You can share the list of left-out rows afterwards.
- Numbers with no name in the list are added as "Member 0XXXXXXXXX" and
  give their own name when they sign in.
- People without a zone in the file go into **Unassigned** (the default), so
  each chooses their own zone once; or into one zone you pick; or are left
  out.
- Imported members may check and correct their own name, contact details
  and choose their zone, one time only (Me > Edit my details and zones).
  After that you, the General Secretary or their Zone Secretary change it. Members you register later are
  updated by the Founder, General Secretary or the member's Zone Secretary
  or Mayor.
- To tell members their IDs, tap the chat icon at the top of Members (**Send
  IDs on WhatsApp**). Tap **Send to the next person** again and again to go
  through everyone. Each person has a Send button that opens WhatsApp with
  their message ready; you tap send in WhatsApp. People you have opened show
  a green tick until you leave the screen.

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

## Payment requests (More > Payment requests)

The Treasury or the Welfare Committee asks members to pay; members report
how they paid; a treasurer confirms, which writes the receipt. How each
step works is in the user guide.

- **Who can ask:** for the Treasury, anyone whose role can record payments
  or manage dues; for Welfare, anyone who can prepare, approve or pay
  welfare. Zone officers ask their own zones only.
- **Who can confirm:** anyone whose role can record payments or pay
  welfare, never for their own payment. Zone treasurers see and confirm
  their own zones' members only. Confirmed receipts are numbered
  `ONL-YYYY-000001` so they never clash with phone receipts, and are voided
  like any other receipt.
- **Checking is by hand for now.** The app does not see the MoMo account,
  so the treasurer matches each transaction ID against the MoMo or bank
  messages before confirming. Automatic MoMo checking (members pay inside
  the app and the receipt is written by itself) needs a merchant account
  with MTN MoMo, Telecel Cash or a payment company such as Paystack or
  Hubtel; see phase 4.

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

## The member web app (iPhone and any browser)

Members who do not have the Android app open **https://jbf-members.onrender.com**
in their phone's browser. On an iPhone use Safari, tap the Share button, then
**Add to Home Screen**; on Android use the browser menu. It installs with the
JBF logo and opens like an app. They sign in with their member ID and
password (first time: **Activate** with member ID and phone number), see
their ID card, dues, payments, events, executives and chats, and, if they were
on the founding list, correct their details and choose their zone once.

### The full app in a browser (executives on iPhone)

Executives can also run the whole JBF app in a browser at
**https://jbf-app.onrender.com** (iPhone: Safari, Share, **Add to Home
Screen**). Sign in with your member ID like on Android. It syncs through the
cloud like a phone. Limits: no backup/restore or field-phone files, no member
photos, no reminders or fingerprint sign-in, and the data kept in the browser
is not encrypted, so use it only on your own phone. Clearing Safari data
removes it, but signing in again re-downloads everything.

## Safety and upkeep

- **Daily cloud copies.** Every night at 02:00 the cloud keeps a snapshot of all records, in seven rolling days. CoreIntel support can restore one if records are ever lost.
- **Browser sign-out.** The web app signs out after 15 quiet minutes and, when you sign out, erases what the browser stored (after sending any unsent changes). Sign in again online with your member ID.
- **Activation progress.** The dashboard shows how many members have activated their sign-in.

## Elections

Only the Electoral Commission (Chairperson and Secretary) runs elections. Everyone else just votes.

1. **Commission officer 1** opens More > Elections > New election, names the posts and sets the closing time, then adds each candidate (search the member, add a picture and a short message). Commission officers cannot stand.
   Until voting opens, a Commission officer can tap **Change details** to change the name, notes, closing time, posts and seats (or take a post out), and tap a candidate to change their picture or message, swap them for another member, or **Take off the ballot**. **Cancel election** removes a draft from the list; it stays in the election record.
2. **Commission officer 2** (a different person) opens the voting. At that moment the voters list is fixed to all active members, and candidates can no longer change.
3. Each member signs in with their own member ID, opens Elections and chooses one candidate per post (or abstains). One vote each, final, and secret: the ballot box holds no names or times.
4. Nobody, the Commission included, can see counts while voting is open, only how many have voted. Voting closes at the set time (or early, by an officer other than the one who opened it).
5. Everyone then sees the results with the winners. The record of every step is chained so tampering shows.

The Founder cannot run or change an election. The main phone's old username login cannot vote; use the member ID sign-in.

### Who is on the Electoral Commission

Open More > Elections > Electoral Commission. The **Founder** and **General Secretary** appoint the Chairperson (and can add or remove anyone). The **Chairperson** then adds the Secretary and members. Nothing changes while voting is open, and a candidate cannot join. The Commission is kept separately from the ordinary role list, so giving someone a role does not put them on it. The Founder can appoint from the main phone; voting and running elections need the member ID sign-in.

## Who makes announcements

General announcements in the Announcements chat are made by the **Founder**, the **General Secretary**, the **Welfare Secretary**, the **Organising Committee Secretary**, and the Secretaries of the other committees: the **Disciplinary Committee Secretary** and the **Electoral Commission Secretary**. Zone Secretaries are in the Secretariat, so they do not make general announcements. Instead each **Zone Secretary** and **Zone Mayor** posts in their zone's announcements chat, which only that zone's members read.

Give the roles on each member's page as usual. The Organising Committee Secretary is a new role; it also leads the Organizing office with the Organizer. A role with the "Post announcements to all members" permission (More > Roles) can also make general announcements, so the Founder can add someone without an update. For another organisation, CoreIntel changes the list in the cloud table `announce_roles` (role key, and `all` or `zone`).

## Committee offices

Each committee gets its own digital office in the app, open only to the people on that committee. The Electoral Commission is the first; the next committees (Welfare, Treasury and so on) plug in the same way.

Commission members find it on the More screen (or the member home) under **My committee office**, and in More > Elections > **Commission office**. It needs internet and the member ID sign-in. The Founder and other officers do not see inside it unless they sit on the Commission.

The office has four tabs and a private chat (the speech-bubble button):

- **Overview**: the Commission's members and roles, each election with its checklist progress and turnout, the **voter roll** (active members, and how many have activated their sign-in, zone by zone, so you know whom to remind before voting opens), and recent activity.
- **Tasks**: anyone in the office adds a task, gives it to a member and sets a due date, and anyone ticks it done. For each election the Chairperson or Secretary can tap **Add the standard steps** on the Overview to add the usual checklist (timetable, nominations, vetting, candidate list, ballot, opening, reminders, results, complaints).
- **Minutes**: meeting minutes, decisions and notes, kept for later. The writer, the Chairperson or the Secretary can change or remove an entry.
- **Notices**: the Chairperson or Secretary posts notices (for example "Nominations are open"). Every member sees them at the top of Elections, in the app and on the member website. A notice can be withdrawn. So the Treasurer, the Organizer and the Welfare Chairman post their offices' notices too.

Every change is written to the office's activity list. Office records live in the cloud only, like elections.

### Disciplinary Committee office

The second office. Its members are whoever holds a Disciplinary Committee role: the Founder or General Secretary gives these roles on the member's page under **Roles and access**, as **Disciplinary Committee Chairperson**, **Disciplinary Committee Secretary** or **Disciplinary Committee** (member). The Chairperson and Secretary lead the office.

- **Cases** (on the Overview): open complaints and warnings sent, and the latest cases, open ones first. Complaints still come from Zone Mayors, Zone Secretaries and the General Secretary on a member's page. **Open the case book** to send a warning or close a complaint, as before.
- For each open complaint, the Chairperson or Secretary can tap **Add the hearing steps**: acknowledge the complaint, tell the member, hear the member, hear the zone and witnesses, decide and record the decision in Minutes, then warn or close. Each case shows how far its steps have got.
- Tasks, Minutes and Notices work as in every office. The office chat is the committee's existing Disciplinary Committee chat, which the Chairperson and Secretary now join too.
- Notices from any committee appear on every member's home page.

### Organizing Committee office

The third office. The national **Organizer** leads it; **Zone Organizers** and **organizing helpers** are its members. They join automatically from their roles (given on the member's page under **Roles and access**).

- **Events** (on the Overview): planned events soonest first, then the latest held ones, with the date, venue and how many attended. Events are still created in More > Events and meetings.
- For each planned event, the Organizer can tap **Add the planning steps**: agree the date, venue and budget, book the venue, arrange transport and accommodation, announce it, arrange any Silver Collection, share the attendance QR codes, take attendance, and report attendance and spending afterwards. Each event shows how far its steps have got.
- Tasks, Minutes and Notices work as in every office. The office chat is the existing Organizing chat.

### Welfare Committee office

The fourth office. The **Welfare Chairman** and **Welfare Secretary** lead it; the **Welfare Treasurer**, welfare committee members, **Zone Welfare Officers** and **Zone Welfare Helpers** are its members. They join automatically from their roles.

- **Welfare cases** (on the Overview): how many cases wait for approval and how many are approved but not yet paid, what is still to pay and what has been paid, then the latest cases with the member, case type, amount and who prepared and approved them. Zone Welfare Officers and Helpers see only the cases of members in their own zones; the national team sees all.
- **Benefit amounts**: any amount the Treasurer has proposed that still waits for the Chairman, and how many case types have no amount yet.
- For each open case, the Chairman or Secretary can tap **Add the case steps**: confirm the details with the member's zone, check the member is in good standing, prepare the case with the fixed benefit, approve it (Chairman, or Secretary if the Chairman is away), pay and record the payout, and visit or call the family. Each case shows how far its steps have got.
- Cases are still prepared, approved and paid in More > Welfare, with the same rules as before. The office is where the team plans and follows up. The office chat is the existing Welfare chat.

### Secretariat office

The fifth office. The **General Secretary** leads it; **Zone Secretaries** are its members. They join automatically from their roles.

- **Membership register** (on the Overview): active members and how many have activated their sign-in, how many are suspended, inactive or deceased, and the records still to complete (members who have not picked their zone, or have no phone number or emergency contact). The latest status changes are listed. Zone Secretaries see only their own zones.
- **Meetings**: upcoming meetings soonest first, then the latest held, with attendance, and whether the agenda and minutes have been written. Zone Secretaries see their zones' meetings and association-wide ones. Meetings, agendas and minutes are still written in More > Events and meetings.
- For each meeting, the General Secretary can tap **Add the meeting steps**: agree the date and agenda with the Chairperson, send the notice and agenda, prepare the attendance register or QR codes, take attendance, write the minutes, have them adopted at the next meeting, and follow up on the decisions.
- Tasks, Minutes and Notices work as in every office. The office chat is the existing Secretariat chat.

### Treasury office

The sixth office. The **Treasurer** leads it; **Zone Treasurers** and the **Welfare Treasurer** are its members. They join automatically from their roles.

- **This month** (on the Overview): money received and paid out (expenses and welfare payouts), the number of receipts and any voided ones, welfare cases approved but not yet paid, and the totals by contribution type and by collector, so the Treasurer can check each collector's money.
- **Monthly dues**: how many active members have paid this month's dues.
- **Amounts waiting**: any dues amount the Treasurer has proposed that waits for the Founder or General Secretary, and monthly dues with no amount yet.
- Zone Treasurers see only payments from members in their own zones, and not the association's spending.
- **Month end**: for this month and last month, the Treasurer can tap **Add the month-end steps**: collect the money and receipt books from the Zone Treasurers, bank it, check receipts against the bank, record every expense, pay approved welfare cases, review voided receipts, prepare the finance report and present it to the executives.
- Payments, expenses and dues are still recorded in Payments, More > Expenses and More > Contribution types, with the same rules. The office chat is the existing Treasury chat.

### Leadership Council office

The seventh office. The **Founder** and the **General Secretary** lead it. Its members are the **Directors** (and Patron), the **Organizer**, the **Treasurer**, the **Welfare Chairman** and every zone executive (Mayor, Deputy Mayor, Secretary, Treasurer, Organizer and Welfare Officer). They join automatically from their roles. The office uses the existing Leadership Council chat, which now also includes the Welfare Chairman.

- **Waiting for the Council** (on the Overview): dues and welfare benefit amounts waiting for approval, welfare cases waiting for approval, open complaints with the Disciplinary Committee, and national posts that no one holds yet.
- **Zones**: each active zone with its Mayor, active members, how many of its 6 executive posts are filled (and which are missing), and how many members have paid this month's dues.
- **Council meetings**: executive and general meetings, with attendance, agenda and minutes. The Founder or General Secretary can tap **Add the meeting steps**: circulate the agenda, collect a report from every Zone Mayor and from the committees, hold the meeting and take attendance, record the decisions, and follow them up. These steps are separate from the Secretariat's own meeting steps.

### Executive Council office

The eighth office. The **Founder** and the **General Secretary** lead it. Its members are the **Directors** (and Patron), the **Treasurer**, the **Organizer** and the **Auditor**. They join automatically from their roles. The office uses the existing Board chat, which now also includes the Auditor.

- **Money** (on the Overview): received and paid out this month and this year, and the money held according to the app's records (everything received less everything paid out since records began in the app; it does not include any opening balance from before).
- **Waiting for a decision**: dues amounts waiting for the Founder or General Secretary, monthly dues with no amount yet, welfare benefit amounts and cases waiting for approval, and open complaints.
- **Committee offices**: every other office with its number of members, open and late tasks, and when it was last used, so the Council can see which committees are working.
- **Executive meetings**: the Founder or General Secretary can tap **Add the meeting steps**: agree the agenda with the Founder, send papers a week before, review the finance report and committee reports, hold the meeting, record the decisions and follow them up.

For another organisation, CoreIntel adds or renames committees in the cloud table `office_committees` (which roles are members, which roles lead, and the standard checklist); no app update is needed.

## Welfare membership and the welfare contribution

Welfare is by choice. Not every member is in welfare.

- A member is **not in welfare**, a **welfare member**, or **disqualified**.
  A member joins on their own page (Me tab, or the website), or an officer
  with the welfare permission presses **Join** on the member's page.
  Paying welfare dues or a **Welfare contribution** also makes them a welfare
  member automatically.
- **Monthly welfare dues** are owed only by welfare members, from the day
  they joined. Members outside welfare owe nothing and are not in defaulters.
- **Welfare contribution** is a type with no fixed amount. Set a **Minimum
  amount** in More > Contribution types; payments below it are refused.
  Ask for it through a payment request like any other type.
- **Three payments missed in a row** (three finished months of welfare dues,
  or three finished welfare contribution requests) disqualifies a member.
  Welfare cases cannot be created for them. The check runs every night and
  when a request is closed. A Welfare Chairman, Secretary or other holder of
  the welfare approve permission presses **Reinstate** on the member's page;
  dues then start again from that day.
- Paying does not bring back a disqualified member, only reinstatement does.
- Phones must update: an older build saving a member wipes these fields.

## Members paying their own dues

Members do not have to wait for a request. In the app (More, or the member site's Payments tab) they tap **Pay my dues**, choose what they are paying for (and the month for monthly dues), pay the Treasury's Mobile Money number, and enter the transaction ID from the payment message. The Treasurer confirms it in **Payment requests**, which writes the receipt like any other.

The Treasurer sets the Mobile Money number members see: **Payment requests**, then the phone icon at the top (**Where members pay**). Until it is set, members are told to ask the Treasurer for the number.

Paying inside the app by Mobile Money or card, with no confirmation step, needs a CoreIntel payment provider account (for example Paystack or Hubtel). It is not switched on yet.
