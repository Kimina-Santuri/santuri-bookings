# Connect Santuri accounts and bookings

The implementation stays in this GitHub repository. The public site is still static HTML/CSS/JavaScript; Supabase provides Auth, Postgres, Storage and one scheduled Edge Function. No framework migration or separate application server is required. Nothing has been published by this change.

## What is included

- `account.html`: registration, verified email/password sign-in, and password reset requests.
- `dashboard.html`: own profile, active membership, upcoming bookings and weekly balances.
- `book.html`: one date-first custom calendar showing open slots across every connected space in Nairobi time.
- `bookings.html`: bookings, cancellations and calendar-file downloads for confirmed sessions.
- `admin.html`: staff-only space editing, image uploads, weekly opening days/times, archiving/restoring, booking approval and attendance, blocked times, alumni confirmation, paid membership activation, payment records, allowance adjustments and audit history.
- `reset-password.html`: completes the email recovery flow.
- A connected catalog updates both the homepage cards and Spaces page. Unconfigured sites retain the existing Calendly flow. Archived spaces disappear from connected listings and stop accepting new bookings; their historical records stay intact.

With no connection, account actions are unavailable and `/admin.html` shows a clearly labelled, read-only preview using the existing four spaces. There are no fake users, demo payments or browser-local booking records.

## 1. Create Supabase

Create one project in the Santuri-owned Supabase organisation. Keep its database password and secret/service-role keys private. Use the project URL and **publishable** key for the browser configuration only.

For a real launch, select a production plan with backups. Free is suitable for initial testing but may pause after inactivity and does not include automatic backups. Accounts remain disabled by default in `assets/js/config.js`.

## 2. Install the database

Use the Supabase SQL Editor to run, in order:

1. `supabase/migrations/202609070001_booking_system.sql`
2. `supabase/migrations/202609070002_staff_balances_and_sync_lock.sql`
3. Any later numbered migration in filename order.
4. `supabase/seed.sql`

Alternatively, a developer can link the project and apply migrations using the Supabase CLI (`supabase link`, `supabase db push`), then apply the seed once. Do not reset a production database. The seed only adds missing slugs and does not overwrite staff edits.

The migration creates restricted tables/functions, an image bucket and the new-user profile trigger. It does not create staff users or assume operating days. If Auth already contains users before the migration, backfill profiles before using the website:

```sql
insert into public.profiles(id,email,full_name)
select id,coalesce(email,''),left(coalesce(raw_user_meta_data->>'full_name',''),150)
from auth.users
on conflict(id) do nothing;
```

## 3. Configure sign-in and your existing email provider

In Supabase Authentication:

- Enable email/password signup and email confirmation; use a minimum password length of 12.
- Set Site URL to the approved website origin.
- Add exact redirect URLs for `book.html` and `reset-password.html`, for both the live origin and any approved local testing origin. Local development uses `http://127.0.0.1:8080`.
- Configure custom SMTP using the existing `santuri.org` email provider if it supports automated transactional mail. The provider must supply SMTP host, port, username, password and an approved sender. Put the password in Supabase, never in GitHub or frontend JavaScript. Check SPF/DKIM and sending limits with the provider.
- Keep verification and password-reset templates enabled. PKCE links should be opened in the same browser that requested them; request a fresh reset link if browser storage was cleared.

These SMTP settings cover account email. Booking notifications use the separate `email-notifications` Edge Function and the durable outbox in `202609080004_booking_email_notifications.sql`. Deploy that function, add its secrets (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`, `SMTP_SENDER_NAME`, and a random `EMAIL_NOTIFICATIONS_SECRET`), then run `supabase/schedule-email-notifications.sql` with private placeholders replaced. The function sends request received, confirmation, cancellation, completed, no-show and next-day reminder messages. Do not put the Zoho password in GitHub or frontend JavaScript.

## 4. Connect the site and appoint staff

Edit `assets/js/config.js` with the project URL and publishable key. Set `accountsEnabled: true` only in the local/testing checkout initially.

Create and verify the first staff account through `account.html`. In the SQL Editor, grant staff access to that specific, verified account:

```sql
insert into private.staff(user_id)
select id from auth.users
where lower(email) = lower('REPLACE_WITH_VERIFIED_STAFF_EMAIL')
  and email_confirmed_at is not null
on conflict do nothing;
```

Only an owner using the SQL Editor or an existing staff member using the Members screen can grant/revoke staff. Staff access is an internal membership option, never a public paid tier: it gives unlimited space hours and no rental charge, with no expiry until an administrator revokes it. User-editable signup metadata never grants roles or alumni status. Staff permissions are checked on every database mutation.

Sign in again and open Staff dashboard. For each space, review its confirmed details, select actual opening days, set opening times within 09:00–18:00, and enable booking requests. Seeded spaces are visible but closed to the custom calendar until this step is complete. Existing Calendly fallbacks remain usable while bookings are closed.

If several production stations can be booked simultaneously, add one bookable resource per physical station. Each space record represents one exclusively booked resource; capacity is the number of people in one session, not the number of simultaneous bookings.

## 5. Connect Google Calendar

Use one dedicated Google calendar per bookable space. Bookings are authoritative in Supabase. Edit/cancel bookings in the staff dashboard; external Google events block availability but do not modify a member's booking or allowance.

1. In a Santuri-owned Google Cloud project, enable the Calendar API and create a service account. Generate its private key and store it privately.
2. Share each resource calendar with that service account's email, granting permission to make changes to events. Workspace sharing policies must permit this; check with your administrator if access is denied.
3. Set Edge Function secrets in Supabase: `GOOGLE_SERVICE_ACCOUNT_EMAIL`, `GOOGLE_PRIVATE_KEY` (the PEM private key), and a randomly generated `CALENDAR_SYNC_SECRET` of at least 32 random bytes. Supabase supplies `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to the function. Never share these secrets in chat or commit them.
4. Deploy the included `calendar-sync` Edge Function. The CLI command is `supabase functions deploy calendar-sync --no-verify-jwt`. Platform JWT verification is disabled because this is a scheduled endpoint: the function verifies the separate `x-sync-secret` header and accepts POST only. Do not expose this secret in the website.
5. In Staff dashboard → Calendar & bookings, enter each calendar ID (Google Calendar → Settings → Integrate calendar).
6. Schedule the Edge Function every five minutes using Supabase Cron/HTTP. Store the function URL and sync secret in Supabase Vault; use the supplied `supabase/schedule-calendar-sync.sql` template, replacing its placeholders in the SQL Editor. The secret must match the function secret.
7. Invoke a run and verify the dashboard's last-sync time and Google events. A connection older than ten minutes, an error, or a conflicting Google event closes new booking slots until resolved.

The function creates deterministic event IDs and uses a durable revision queue for retries. Only one run holds the sync lease at a time. It imports recurring instances, timed busy events and all-day events for the booking horizon. Event details sent to Google contain the room and time, not member email, name or payment information. Event invitations are not sent by the service account; confirmed members can use Add to calendar.

Google and Supabase do not share one transaction. There can be up to one sync interval before an external Google change is reflected. For a strict no-conflict workflow, staff should block availability here and avoid concurrent scheduling in Google. Imported conflicts are flagged and stop new requests. Existing bookings are retained for staff resolution. The database itself serializes simultaneous requests and rejects overlapping sessions.

Replacing or disconnecting a resource calendar is deliberately not exposed as a casual edit: migrate/delete its old booking events first. Failed sync jobs retry on subsequent runs. A large backlog may need multiple runs; monitor the function and dashboard before opening bookings.

## 6. Membership and payment rules

- Paid activation requires confirmed alumni eligibility and in-person payment verification. The server records the payment and starts exactly 30 consecutive days in one transaction. It refuses overlapping active memberships.
- Mwanzo: 60 production minutes/week; Midi: 240 production minutes and two two-hour studio sessions/week; Sana: 480 production minutes/week.
- Sana's studio frequency is unconfirmed. No automatic studio allocation is created. Staff may grant a specifically approved number of sessions for a selected Monday-starting week, with a recorded reason.
- Allowances refresh Monday at 00:00 Nairobi time and do not carry over. A session uses the allowance week in which it starts. A membership must cover the entire session.
- Requested and confirmed bookings reserve allowance immediately. Completed and no-show sessions consume it. Eligible cancellations release it. Staff can override cancellation notice with a reason. Members cannot cancel within 12 hours.
- Production/studio requests always require at least 24 hours, even if staff enter a shorter general notice period.
- No-show and completion marking happens after a confirmed session ends. Requests require explicit team approval. Staff should review pending and elapsed bookings daily; requests do not expire automatically.
- Non-allowance booking prices are calculated on the server from the hourly rate and eligible Midi/Sana discount. Existing bookings retain their price snapshot when a space rate changes.
- Manual booking payments can be partial. Duplicate references and payments above the balance are rejected. Voiding a booking payment changes the ledger, not a bank/M-Pesa transaction; no refunds or money transfers happen here.
- Membership payment reversal/early termination requires a reviewed correction of membership and usage records. It is not automated in this version.
- Bookings are cancelled and re-requested when their time needs to change; there is no drag-to-reschedule action in this version.

## 7. Verify before launch

From the repository:

```sh
npm install
npm run build
npm test
npm run check
npm run dev
```

The build copies only public pages/assets into `dist/`. It bundles the pinned Supabase browser client so production does not depend on a third-party JavaScript CDN. Keep `assets/vendor/supabase.js` with the website when using direct static hosting from GitHub; rebuild it when dependencies change.

Automated tests run the actual migrations in local PGlite/Postgres with mocked Supabase Auth/Storage schemas. They cover database permissions, booking rules, allowances, payments, archives, calendar gating and image upload policies. They do not replace a real Supabase/Google/SMTP integration test, and PGlite's single connection cannot prove multi-session lock behaviour.

On the connected staging project, verify with two ordinary accounts and one staff account:

- Signup, verification, recovery, sign-out and session expiry.
- Ordinary users cannot read other users' records or mutate prices, payments, memberships or staff roles through direct API requests.
- Competing requests from separate sessions produce only one reservation for a slot; allowance limits also hold across different spaces.
- Staff space creation, image upload, schedule editing, archive and restore update both catalog pages.
- Member and staff calendars show the same connected spaces and date-based open-slot rows; selecting a slot still goes through the server-side booking and allowance checks.
- Google create/update/cancel retries, external busy blocks, all-day events, failed/stale sync, and overlapping imported events.
- Week boundaries, expiry, cancellation, no-show, payment correction and member dashboard balances.
- Keyboard navigation, dialogs, narrow mobile layout and reduced-motion behaviour.
- Review the account/privacy wording, retention process and backups with the Santuri team.

Use the current GitHub release process only after explicit approval. Do not publish, push, change Sites previews or update the custom domain just to perform setup. Keep `.openai/hosting.json` unchanged.

## Official references

- Supabase Auth: https://supabase.com/docs/guides/auth/passwords
- Database permissions: https://supabase.com/docs/guides/database/postgres/row-level-security
- Storage permissions: https://supabase.com/docs/guides/storage/security/access-control
- Scheduled Edge Functions: https://supabase.com/docs/guides/functions/schedule-functions
- Google Calendar events: https://developers.google.com/workspace/calendar/api/v3/reference/events
