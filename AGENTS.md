# Santuri Bookings — Agent Guide

## Project overview

This is a lightweight static booking and information website for Santuri East Africa's creative spaces in Nairobi. Keep it framework-free unless the user explicitly requests a migration. Calendly provides scheduling.

## Working rules

- Keep changes local unless the user explicitly asks to publish or push.
- Do not update the private Sites preview or the live custom domain by default.
- The canonical GitHub repository is https://github.com/Kimina-Santuri/santuri-bookings.
- Use the main branch for approved releases. Never force-push; fetch and preserve remote history before publishing.
- Do not invent operational details, equipment inventories, policies, prices, capacities, or availability.
- Preserve the monochrome black-and-white visual system and the interactive topographic canvas background.
- Maintain responsive behavior, keyboard access, visible focus states, and reduced-motion support.
- Retain direct Calendly URLs as fallbacks whenever using the embedded popup launcher.
- Use bookings@santuri.org for booking enquiries.

## Important files

- index.html: booking-focused homepage
- spaces.html: detailed editorial information about each space
- membership.html: Santuri Membership Program tiers, joining instructions, and operational rules
- assets/css/main.css: shared styles for every page
- assets/js/main.js: room data, filtering, Calendly launchers, analytics hooks, and canvas animation
- booking-policy.html: operating terms and house rules
- privacy.html: privacy information
- assets/images/: optimized production images
- images/: original source images
- sitemap.xml and robots.txt: search-engine discovery files
- account.html, dashboard.html, book.html, bookings.html, admin.html and reset-password.html: authenticated booking, membership and staff screens
- supabase/migrations/: versioned database schema, permissions, staff access and notification outbox
- supabase/functions/calendar-sync/: Google Calendar synchronization Edge Function
- supabase/functions/email-notifications/: queued Zoho SMTP booking notification Edge Function

## Confirmed business information

- Opening hours: 09:00–18:00
- Minimum booking: one hour
- Standard space rate: 1,000 KES per hour
- Studio capacity: five people
- DJ practice room capacity: three people
- Classroom capacity: twenty people
- Workstation capacity: one person
- Staff are available to help.
- Studio engineers can be arranged for 2,500 KES per hour.
- NURA JCK runs regular CDJ practice sessions: Fridays in the DJ Practice Room and Saturdays from 11:00–19:00 in the Classroom.
- Address: Santuri East Africa, Basement, The Mall, Chiromo Road / Ring Road Westlands, Nairobi, Kenya

## Membership program

- The Santuri Membership Program (SMP) is for Santuri Alumni.
- Paid memberships run for 30 consecutive days from payment confirmation.
- Allowances listed per week refresh every Monday, expire at the end of Sunday, and do not carry over.
- All sessions, spaces, and equipment are subject to availability and confirmation by the Santuri team.
- Paid tiers are Santuri Mwanzo at 500 KES, Santuri Midi at 1,500 KES, and Santuri Sana at 3,000 KES per membership period.
- Mwanzo includes one production-station hour per week, no pro studio sessions, sound technician availability, and standard gear and space rates.
- Midi includes up to four production-station hours per week, two two-hour studio sessions per week, sound technician support during studio sessions, and 30% gear and space rental discounts.
- Sana includes up to eight production-station hours per week, sound technician support during studio sessions, and 50% gear and space rental discounts. The frequency of its four two-hour studio sessions still requires team confirmation; do not add a frequency until confirmed.
- The Free Tier includes limited consultations, free Wi-Fi, shared table space, and communications about opportunities and volunteer roles through the alumni mailing list and WhatsApp group.
- Payment uses Paybill 4054299 with the member's name in capital letters as the account reference. Activation happens in person after showing payment confirmation to the Santuri team.
- Expired paid memberships revert to the Free Tier.
- Members can book and cancel up to 5 hours before a session (changed from 24 hours' booking and 12 hours' cancellation notice on 2026-10-20). No-shows forfeit the relevant weekly hours.

## Experience and content

- Homepage cards should remain compact and comparison-friendly.
- On wide screens, show all four homepage cards in one row; step down to two columns on tablets and one column on mobile.
- Keep the homepage and card area white with subtle outlines, black type, and black primary actions.
- Landing-page navigation and calls to action that mention “space,” “spaces,” or “find your space” should lead to spaces.html.
- “View details” links should open the matching section of spaces.html.
- Booking actions should use the Calendly popup when its script is available and retain working direct-link fallbacks.
- The Spaces page uses the large room images in assets/images and alternates image/text feature sections.
- Keep the DJ feature compact: its portrait source is displayed in a cropped 4:3 frame focused on the performer and equipment.
- The Visit section uses a two-column address-and-square-map layout on desktop and stacks on mobile.
- The black “Need help?” strip sits below the Visit address/map row and must remain full-bleed to both viewport edges and the bottom of the section.
- The main footer is white so the original black logo remains visible without inversion.
- The header is sticky and uses a deliberately small logo.
- Inclusion wording: “Everyone is welcome at Santuri.” Harassment or discrimination of any kind is not tolerated.
- House rules cover closed drink containers, no indoor smoking or vaping, safeguarding personal belongings, respectful conduct, and responsible equipment use.

## Local verification

Serve the repository as static files and check index.html, spaces.html, membership.html, booking-policy.html, privacy.html, account.html, dashboard.html, book.html, bookings.html, admin.html, and reset-password.html. Run `npm run check`, `npm run build`, and `npm test` after JavaScript, database or calendar changes. Validate assets/js/main.js after JavaScript edits and confirm all referenced images exist.

## Booking backend state

- The repository now includes an optional Supabase Auth/Postgres/Storage booking system. The public site remains framework-free and Calendly remains the fallback until a space is enabled for online booking.
- Supabase project: `gudbkpwxszdtirewawep`. The public publishable connection is in `assets/js/config.js`; never put a secret, service-role key, Google private key or SMTP password in frontend files.
- The Supabase schema and permissions are in `supabase/migrations/`, with a one-time new-project installer at `supabase/setup.sql` and existing-space seed at `supabase/seed.sql`.
- Kimina's verified `kimina@santuri.org` account is a staff account in `private.staff`. Staff access is granted only through the database or the authorised admin Members screen; signup metadata must never grant roles, alumni eligibility, payment status or allowances. Staff access is an internal membership option with unlimited hours and no rental charge, and is revoked by staff when needed.
- Account pages are `account.html`, `dashboard.html`, `book.html`, `bookings.html`, `admin.html`, and `reset-password.html`. The member booking flow is space-first, then a date-based monthly grid with open times. The staff view shows all active spaces, bookings and blocks.
- The system records profiles, memberships, bookings, payments, allowance adjustments, space hours, blocked times, calendar connections and an audit log. Booking, payment, allowance and staff mutations must continue to go through the checked database functions.
- The staff booking screen shows the latest 200 requests across all dates, with an optional space filter and Confirm, Cancel, Completed and No-show actions. Members land on the full space-first monthly booking calendar after sign-in; the dashboard remains available for balances, bookings and profile details.
- Migration `202609080004_booking_email_notifications.sql` adds a private, retryable email outbox. It queues request received, confirmed, cancelled, completed, no-show and next-day reminder messages. The `email-notifications` Edge Function sends them through Zoho SMTP; SMTP credentials and `EMAIL_NOTIFICATIONS_SECRET` must remain Supabase secrets.
- Supabase Auth production redirects use `https://bookings.santuri.org/book.html` and `https://bookings.santuri.org/reset-password.html`, with local `127.0.0.1:8080` redirects retained only for laptop testing.
- Google Calendar sync is deployed as the `calendar-sync` Supabase Edge Function and runs through Supabase Cron. Studio (`studio@santuri.org`), DJ Practice Room (`djpractice@santuri.org`), Classroom (`c_4ac8f2fd22a525d9ec1a0d4dd280517c66b353cee4198cfb3cb3ea222c7113db@group.calendar.google.com`) and Creative Workstation (`c_d6a6b0ecf67e7d36185da732e86334adad6e48d9065b42b8ddc7f4676d3d1d4e@group.calendar.google.com`) are now connected. Classroom and Workstation `synced_at` values should be verified after the next scheduled sync; any `sync_error` must be resolved before enabling their bookings.
- The downloaded Google service-account JSON is local-only and ignored by `.gitignore`. Never commit it, paste it into chat, or place its private key in the website.
- Sana's studio-session frequency remains unconfirmed. Do not add an automatic frequency; staff may record a specifically approved weekly session adjustment with a reason.
- Nothing from the backend build has been published or pushed by default. Keep `accountsEnabled` and live redirects aligned with the environment being tested, and do not update Sites or the custom domain without explicit release approval.

## Next release steps

1. Apply `202609080003_staff_membership.sql` and `202609080004_booking_email_notifications.sql` in the connected Supabase project if they are not already applied.
2. Deploy `email-notifications` with `--no-verify-jwt`, set its Zoho SMTP and shared-secret Edge Function secrets, and run `supabase/schedule-email-notifications.sql` with private placeholders replaced.
3. Create a test client account and complete a full staging booking: submit a request, confirm it as staff, verify the Google event, record a payment, check the member balance and check request/confirmation emails.
4. Test cancellation emails, completed/no-show messages, next-day reminders, a time occupied in Google, a Google all-day holiday block, weekly allowance reset, membership expiry and an image upload.
5. Classroom and Creative Workstation calendars are connected and syncing, and both now show "Bookings open" in the Staff dashboard (observed 2026-09-19), so this step appears already done. Confirm with the team that their current opening schedules were the intentionally agreed ones, not just left at defaults.
6. Review the privacy wording, data-retention process, backup plan, staff list and Sana studio allowance decision with the Santuri team.
7. Only after staging checks pass, build the release, commit the approved files and publish through the existing GitHub/Sites process. Never commit service-account JSON, SMTP passwords or other secrets.

## Current repository state

- The completed redesign was pushed to origin/main on 2026-09-03.
- Landing-page space navigation was updated and pushed to origin/main on 2026-09-04.
- The Santuri Membership Program page and its site-wide navigation links were pushed to origin/main on 2026-09-05.
- The booking-system release and social-preview update were previously aligned at commit 23babdf; see the dated release notes below for subsequent changes.
- GitHub CLI is installed and authenticated as Kimina-Santuri on this machine.
- The repository histories were joined with a normal merge commit; existing GitHub history was preserved without a force push.
- Supabase, Google Calendar, account and notification work is deployed/configured for staging. Do not publish further site changes without an explicit release decision.
- Confirmed temporary online-booking schedule: Recording Studio and DJ Practice Room are open Monday–Saturday, 09:00–18:00 EAT; Sunday is closed; maximum session length is four hours. Keep the minimum session and any future schedule changes configurable through the Staff dashboard.
- Booking requests, staff approval/cancellation, password reset and the notification email flows have been tested successfully. Both `calendar-sync` and `email-notifications` are active in the linked Supabase project; treat their secrets and cron schedules as production configuration that must be checked before release.
- The social-preview image is `assets/images/og.png`; it may be replaced by the team, ideally at a 1200×630 share-card ratio. The current replacement is 3386×1708 and may be cropped by social platforms.
- The homepage space grid includes a clickable NURA x JCK card linking to `nura-jck.html`. Its dedicated page has matching Friday DJ Practice Room and Saturday Classroom booking buttons, with both sessions listed as 11:00–19:00. The buttons open the authenticated booking calendar with the relevant space selected.
- Approved booking events synced to Google Calendar include the booker’s name and space in the event title; pending requests retain a `[Requested]` prefix. This is implemented in migration `202609090005_calendar_booking_names.sql` and the deployed `calendar-sync` function.

## Student access and NURA x JCK release (2026-09-12)

- Staff manually grant/remove Student access in Members. Students receive 480 shared minutes per Nairobi week across all spaces, subject to configured booking availability and approval; hours reset Monday with no carryover. Student access grants no staff privileges or alumni eligibility.
- Migration `202609120001_student_access.sql` has been applied to the connected Supabase project and its API schema refreshed to enable local student testing. Staff access takes priority; Student access uses its own shared pool while assigned, separately from paid-tier allowances.
- NURA x JCK card now uses `assets/images/nura.jpg` and `assets/images/nuralogo.png`.
- The homepage NURA x JCK card is a single keyboard-accessible link to `nura-jck.html`. The dedicated page contains confirmed session details and the Friday DJ / Saturday Classroom booking buttons at the bottom.

- The user approved pushing this complete version to the canonical GitHub `main` branch on 2026-09-12. No separate Sites deployment was requested. Future changes remain local unless approved.
- Verification: all 21 automated tests pass; `npm run check` and `npm run build` pass; all 12 pages respond on the local preview. The connected API resolves student functions and rejects unauthenticated access.

## NURA access — deployed (2026-09-16)

- Staff can grant/remove NURA access in Members. It provides 240 shared minutes per Nairobi week, resetting Monday without carryover, independently of Student and paid-tier allowances. Existing Staff access remains unlimited.
- NURA x JCK appears as a virtual booking card using `assets/images/nura.jpg`, linked via `book.html?space=nura`. Friday sessions reserve the existing DJ Practice Room; Saturday sessions reserve the existing Classroom, between 11:00 and 19:00 EAT (extended from 18:00 on 2026-09-19). It does not create another physical space or calendar.
- Migration `202609150001_nura_access.sql` enforces assignment, the weekly limit, weekday/time restrictions, and the physical room's availability and locking. Normal booking status, notification and calendar-sync paths apply. Cancellation releases hours; completed/no-show bookings consume them.
- Migration `202609150001_nura_access.sql` has been applied to the connected Supabase project and the API schema refreshed. Existing room opening schedules, booking enablement and calendar health still control availability.
- Verified with the connected staff account: Friday 2026-09-18 has 13 one-hour slots in the DJ Practice Room from 11:00–18:00 EAT; Saturday 2026-09-19 has 13 one-hour slots in the Classroom from 11:00–18:00 EAT. Later dates are also resolving through the NURA slot function.
- The user reports switching the email sender to Zepto Mail. This task does not change or verify the deployed SMTP secrets; the local notification function still supports SMTP configuration through secrets.

## Role assignment email notifications (2026-09-16)

- Migration `202609160001_role_assignment_emails.sql` is applied to the connected Supabase project. Granting Staff, Student, or NURA access queues one `role_assigned` message for that member; repeated grants do not send duplicates. Revocations do not send an email.
- The `email-notifications` Edge Function was redeployed with role-assignment message handling. It uses the existing SMTP secrets, including the configured Zepto Mail sender settings; credentials remain Supabase secrets.
- A follow-up worker fix moved booking date/time formatting after the role-message branch. The deployed worker now handles role emails without booking fields; 13 previously failed queued role messages were released for retry on 2026-09-16.

## Staff member access columns (2026-09-16)

- Staff → Members now shows separate Roles and Membership columns. Roles include Staff, Student, and NURA; membership shows the currently active paid tier or Free Tier.
- Migration `202609160002_member_access_summary.sql` is applied to the connected Supabase project. The summary function is staff-only and does not expose private role tables to members.

## Shared staff calendar (2026-09-16)

- The Staff dashboard Calendar & bookings tab is a single month calendar showing all non-cancelled bookings and blocked periods together. Each event includes its time, space, member or block source, and booking status. Staff can move between months and still use Block time + from this tab.
- The shared calendar uses the existing public bookings and space_blocks records; no separate calendar table or external calendar is introduced.

## Shared calendar fix and member view (local, 2026-09-16)

- Fixed the invalid day-zero month boundary in the shared calendar; month navigation handles leap years and December rollover. Multi-day blocks appear on each overlapping Nairobi date.
- `calendar.html` is linked as Shared calendar in every account sidebar and requires sign-in. Staff retain member details and Block time; other members see only spaces, times and statuses.
- Apply `supabase/migrations/202609160003_shared_calendar.sql` before releasing the member view. Its authenticated-only function returns no member identities, notes, payments or block reasons and leaves existing table permissions intact.
- The user approved pushing this change to the canonical GitHub `main` branch on 2026-09-17. The migration still must be applied to the connected Supabase project before the member view works in production.

## DJ Practice Room calendar sync conflict resolved (2026-09-19)

- DJ Practice Room's Google Calendar connection carried a `sync_error` ("Google calendar overlaps an existing booking. Resolve the conflict.") that blocked all online bookings for that space on every date, not just the reported day. The conflicting Google Calendar event (Sept 18, 10:00–19:00, overlapping a confirmed booking) was removed on the Google side by the team; the next scheduled sync cleared the error automatically and the space is bookable again.
- Also found and fixed: DJ Practice Room and Classroom both had `notice_hours` left at the default 24, even though only Recording Studio (studio allowance) and Creative Workstation (production allowance) are documented as needing 24 hours' notice. Since rooms only run 09:00–18:00 (now 09:00–19:00 on Fri/Sat for DJ Practice Room and Classroom, see below), a 24h window on a same-day-ish space wipes out all of "tomorrow" once it's past late afternoon. Lowered both to 2 hours via the staff Edit space form.

## NURA hours extended to 19:00 (2026-09-19)

- The team wants the 6pm start slot to be visible for NURA sessions; since sessions must end by close, the close time needed to move from 18:00 to 19:00 on Friday (DJ Practice Room) and Saturday (Classroom).
- `supabase/migrations/202609190001_nura_extended_hours.sql` drops the `space_hours` table's hard `closes<=18:00` check constraint (found only at the DB schema level, not enforced client-side) and replaces it with `closes<=19:00`; updates `nura_slots` and `request_nura_booking` to allow sessions ending at 19:00; and updates the DJ Practice Room (Friday) and Classroom (Saturday) `space_hours` rows to close at 19:00.
- This migration required DDL (altering a check constraint, replacing functions), which local automation is intentionally blocked from executing; the user ran it directly in the Supabase SQL editor on 2026-09-19 and it is now applied to the connected project. Verified live: `nura_slots` returns an 18:00-19:00 EAT slot on both days. The matching front-end copy and this migration file were committed and pushed to `main` (commit 8e9a827) the same day.
- Side effect to flag: because DJ Practice Room and Classroom share physical `space_hours` with regular (non-NURA) bookings, this also opens an 18:00–19:00 slot for ordinary member bookings on Fridays and Saturdays in those two rooms, not just NURA sessions.

## Staff Bookings tab restored (2026-09-19)

- The 2026-09-16 "Add shared staff calendar view" change replaced the staff tab that had Confirm/Cancel/Completed/No-show actions with a read-only month calendar, but only renamed the old code to `adminCalendarLegacy` instead of keeping it wired to a tab — it was dead code from that point on. This also silently removed the only UI showing Google Calendar connection/sync-error status per space.
- Restored it as its own **Bookings** tab (`adminCalendarLegacy` renamed to `adminBookings`), positioned between Spaces and Calendar & bookings in `assets/js/account.js`. The shared month-view "Calendar & bookings" tab is unchanged and kept as a separate tab.
- Verified with `npm run check`, `npm run build`, and the full test suite (25/25 pass); not click-tested live locally, since transplanting the live auth session to localhost for testing was blocked by a credential-handling guardrail (appropriately).
- Follow-up same day: the Bookings tab filtered one day at a time, which made approving a backlog tedious. Changed it to filter by Nairobi week (Monday–Sunday, matching the existing weekly-allowance convention) with Previous/Next week navigation and a date column per row, since rows can now span multiple days. Committed and pushed as `23cb9a7`.

## Session wrap-up (2026-09-19)

- Everything from this session (DJ Practice Room sync fix, notice-hours fix, NURA 19:00 extension, restored Bookings tab, week view) is committed and pushed to `main` (`23cb9a7`) and applied to the connected Supabase project. Nothing is pending application.
- Two things flagged for a future pass, not urgent: (1) the Google Calendar sync-status table now visible again in the Bookings tab isn't actively monitored by anyone — worth an occasional glance, especially after direct edits to a space's Google Calendar; (2) the untested-scenario checklist in "Next release steps" item 4 above (cancellation/no-show/reminder emails, a Google all-day holiday block, weekly allowance reset, membership expiry, image upload) is still open from the original launch and hasn't been revisited.

## Read-only Supabase MCP access (local, 2026-09-19)

- A `supabase` MCP server (`@supabase/mcp-server-supabase`) is registered with `-s local` scope in `~/.claude.json` for this project only — it is not in `.mcp.json` and is not committed to the repo.
- It runs with `--read-only --project-ref=gudbkpwxszdtirewawep`, so it can query tables (e.g. `calendar_connections`, `bookings`, `space_blocks`) directly for diagnostics but cannot write. This is separate from, and does not change, the existing DDL guardrail: schema/DDL changes still require the human to run them directly in the Supabase SQL editor.
- Auth is a personal access token (account-scoped, not project-scoped) stored as the `SUPABASE_ACCESS_TOKEN` env var in that local MCP config. The token was pasted into a chat transcript during setup rather than entered via shell redirection as intended, so it should be treated as exposed; the user planned to rotate/reissue it at https://supabase.com/dashboard/account/tokens.
- Purpose: let an assistant check live diagnostic state (like a booking space's `sync_error`/`synced_at`) without needing dashboard access or waiting on the user to relay UI screenshots.
- New Claude Code sessions in this directory need to pick up the MCP server at session start; it was not live in the session that added it and required a restart to connect.

## Replaced deleted Google Calendars (2026-09-20)

- The team deleted and recreated the Google Calendars for Recording Studio, Classroom, and Creative Workstation (Recording Studio's old calendar was already failing sync with a 404). The service account email to share any new calendar with is `santuri-booking-sync@santuri-bookings.iam.gserviceaccount.com` (found by reading `client_email` out of the local, gitignored `santuri-bookings-a5b18a367f90.json` service-account key — its private key was never read or pasted).
- Found that the staff "Connect calendar" button (Bookings tab → Google Calendar section, not the read-only "Calendar & bookings" tab) only appears for spaces with no existing connection. `public.connect_calendar` deliberately raises "Disconnecting or replacing a calendar requires a reviewed migration of its events" when a space already has a different `calendar_id` on file, so replacing an already-connected calendar can't be done from the UI at all.
- Wrote `supabase/migrations/202609200001_replace_calendar_connections.sql`, which updates `calendar_id` for the three affected spaces, clears their `sync_error`/`synced_at`, bumps `revision`, and requeues their existing bookings in `private.calendar_jobs` so events get recreated in the new calendars. The user ran it directly in the Supabase SQL editor on 2026-09-20 (per the DDL/data-change guardrail — this session only ran read-only `select`s to check status before and after).
- Verified live: all three spaces synced successfully within one 5-minute cron cycle, `sync_error` is null on all three. DJ Practice Room was left untouched (still on `djpractice@santuri.org`, syncing fine).

## NURA page wording and member phone numbers (2026-09-23)

- `nura-jck.html` booking buttons were simplified from "Friday · DJ Practice ↗" / "Saturday · Classroom ↗" to just "Friday ↗" / "Saturday ↗". The equipment rental line now reads "CDJ3000X and A9 Mixer" instead of "CDJ3000 and V10 mixer". Pushed as `8a5fa4a`.
- Added member phone number collection, per a team request. `supabase/migrations/202609230001_profile_phone.sql` adds `profiles.phone` (text, default '', max 30 chars), updates the `private.new_user()` signup trigger to capture it from `raw_user_meta_data->>'phone'`, and replaces `update_profile(p_name)` with `update_profile(p_name, p_phone)`. The user ran this migration directly in the Supabase SQL editor on 2026-09-23 (per the DDL guardrail); it is applied to the connected project.
- `assets/js/account.js`: the Create Account form now has a required Phone number field passed through `signUp` metadata; the dashboard's "Your profile" panel lets existing members add/edit their phone later (existing accounts default to an empty phone, not blocked). Staff → Members now shows phone in its own **Phone** column (previously stacked under name/email, then split out per follow-up request), and the "Manage member" detail dialog shows it next to the email. Pushed as `56a97fe` and `7eb1c48`.
- Verified live via `curl` against `bookings.santuri.org/assets/js/account.js` that GitHub Pages served the updated file immediately after push; an initial "doesn't show up" report from the user was resolved with a hard browser refresh, not a deploy issue.

## Gear rental (local, 2026-10-06)

- New public page `gear.html` (linked as "Gear" in every header and "Gear rental" in public footers, added to `sitemap.xml`) lists active gear from Supabase via `assets/js/gear.js`. New account page `rent-gear.html` (sidebar "Rent gear") lets signed-in members request gear and track/cancel their rentals; the dashboard shows current rentals when there are any. Staff dashboard has a new **Gear** tab: inventory (add/edit item, price, per-hour or per-day pricing, units owned, available/hidden, optional image in the `space-images` bucket under `gear/`) and a rentals table (member name/email/phone, item × units, rented date, return-by date, actual pickup/return times, status, overdue flag) with Approve / Picked up / Returned / Cancel actions.
- Decisions confirmed by the user: staff choose per-item hour or day pricing; members request and staff approve; Midi 30% / Sana 50% discounts apply automatically when the paid membership covers the whole rental, and staff access rents free; items track a quantity of identical units.
- Implementation choices to confirm with the team: day rentals are counted as inclusive calendar days (pickup 09:00 → return 18:00 EAT, same-day = 1 day, max 30 days); hourly rentals are whole hours within 09:00–18:00 on one day; requests can be made up to 90 days ahead; members can cancel any time before pickup (no notice period invented). Picked-up gear counts as out until marked returned, even past its return date.
- Migration `supabase/migrations/202610060001_gear_rental.sql` adds `gear_items` and `gear_rentals` plus checked functions `gear_quote`, `request_gear_rental`, `set_gear_rental_status` and `save_gear_item`. No items, prices or quantities are seeded. It must be run in the Supabase SQL editor (DDL guardrail) before the gear pages work; until then they show a contact-the-team fallback and the dashboard simply omits the gear panel.
- Not included yet: gear rental emails (the notification outbox/Edge Function only handles bookings and roles) and recording payments against rentals in the Payments tab.
- The NURA page and NURA dashboard panel deliberately keep linking to the Google Form for CDJ/mixer rental (user decision, 2026-10-06); do not switch them to `rent-gear.html`.
- Live inventory (2026-10-06): the gear list from santuri.org/Santuri-Studio was entered through the staff Gear tab with placeholder price 0 and 1 unit, shown in the catalog but marked unavailable until staff set real prices/units. Photos: Santuri's own where available; the user approved manufacturer/product images for the rest (Santuri receives sponsorship and donations from these brands), sourced from santuri.org (Maschine+, Digitakt, TD-3, SM57/58) and official Shure/AlphaTheta product pages (PGA DrumKit 7, MV88+, MV7, CDJ-3000X). Venice F24 (discontinued), microphone stands and isolation panels have no photo. Six items (Push, SP-303, Komplete Kontrol S49, audio interfaces, Adam T5V, iMac) were left for staff to add, with photos prepared locally.

## Staff rescheduling (2026-10-19)

- Staff → Bookings agenda has a **Reschedule** button on upcoming requested/confirmed bookings. The dialog picks date, duration and a free start time (`public.reschedule_slots`) and requires a reason; it calls `public.reschedule_booking`. Both are staff-only (`private.require_staff`), executable by `authenticated` only.
- Migration `supabase/migrations/202610190001_staff_reschedule.sql` (run by the user in the SQL editor on 2026-10-19; anon denial verified via REST). It adds `private.reschedule_ok` (slot rules minus the member notice period, ignoring the booking's own slot), the `booking_rescheduled` email kind, and the two functions.
- Rules: same space only (calendar-sync updates the event inside the current space's calendar, so moving rooms would orphan the old event; change rooms by cancel and rebook). NURA bookings stay on that room's NURA day, 11:00–19:00, up to 4 hours. Allowances are rechecked for the new week (the booking's own units are released when it stays in the same week); studio allowance stays 2 hours. Price is recalculated like `request_booking`; refused if recorded payments exceed the new price.
- Side effects: bumps `private.calendar_jobs.revision` (the status trigger doesn't fire on time changes), deletes any pending `booking_reminder` so a new one is queued, upserts a `booking_rescheduled` email showing old and new times, and audit-logs `booking_rescheduled` with the reason and old/new times and prices.
- `email-notifications` Edge Function redeployed (version 20, `--no-verify-jwt`) before the migration ran. Tests: `tests/reschedule.test.mjs`.

## Five-hour booking and cancellation notice (2026-10-20)

- `supabase/migrations/202610200001_five_hour_notice.sql` lowers member cancellation notice in `set_booking_status` from 12 to 5 hours, removes the hard 24-hour floor for production and studio spaces from `private.slot_ok`, lowers any space with `notice_hours` above 5 to 5, and sets the column default to 5. Spaces already below 5 hours (DJ Practice Room and Classroom at 2) keep their shorter notice. Staff can still change notice per space in Edit space.
- The migration must be run in the Supabase SQL editor before the new copy in `account.js` and `membership.html` matches live behaviour. `supabase/setup.sql` was not updated; it is already behind later migrations.


## Artist directory opt-in (local, 2026-10-24)

- Plan: a public directory of Kenyan creatives, open to anyone in Kenya, seeded from bookings-site sign-ups. A county heat map plus filters by what people do. Bookers contact artists directly from the listing; Santuri sets up no messaging or interactions. **No rankings, ever** (user decision): no popularity or "top" ordering.
- Create account now has an optional "List me in Santuri's public artist directory" box, separate from the required privacy/booking-policy box so it can be refused or withdrawn on its own (Kenya Data Protection Act consent). Ticking it reveals County (all 47) and "What you do" (DJ, Producer, Sound engineer, Vocalist, MC, Instrumentalist, VJ / visuals, Lighting, Photo / video, Event crew; the list lives in `account.js` and still needs team confirmation). The dashboard has an Artist directory panel to opt in, edit or withdraw; it is hidden until the migration is applied.
- Migration `supabase/migrations/202610240001_artist_directory.sql` adds `profiles.directory_consent_at` (null = not listed), `county` and `disciplines`, updates `private.new_user()` to read them from signup metadata only when consent is true, and adds `update_directory(p_listed,p_county,p_disciplines)`. Withdrawing clears county and disciplines. It must be run in the Supabase SQL editor (DDL guardrail) before release. Tests: the directory subtest in `tests/database.test.mjs`.
- `privacy.html#directory` says what a listing shows publicly (name, county, what you do, phone number) and how to withdraw.
- Public page `directory.html` (linked as "Directory" in every header and "Artist directory" in public footers, in `sitemap.xml`), script `assets/js/directory.js`. It shows a county heat map (SVG, square-root shading in six greys because Nairobi would otherwise make every other county look empty), role filters with counts, a county select (the keyboard-accessible equivalent of tapping the map), and cards with Call and WhatsApp links (Kenyan 07/01 numbers become wa.me/254…). Shows 24 at a time with Show more. Order comes from `public.artist_directory()`, which returns listed profiles in random order (name, county, disciplines, phone only; requires county, at least one discipline, name and phone). Before the migration runs, the page shows an "opening soon" message.
- County and role lists live in `assets/js/directory-data.js`, shared with `account.js`. The discipline list was confirmed by the user on 2026-10-24.
- Picking a county (tap or dropdown) zooms the map to it by animating the SVG viewBox (instant with reduced motion), with an "All of Kenya ×" reset button. The SVG has a fixed aspect-ratio so zooming never changes its height (local, 2026-10-24).
- County outlines: `assets/js/kenya-counties.js` (77 KB, 30 KB gzipped; 4000-unit grid, simplified at 1.6 units so zoomed counties aren't blocky), simplified from geoBoundaries KEN ADM1 (CC BY 4.0, credited in the page footer). 'Taita Taveta' and 'Tharaka' were renamed to match the sign-up list.
- Local preview with sample data: `http://127.0.0.1:8080/directory.html?demo`. The `?demo` flag only works on localhost or 127.0.0.1, and it shows a "Sample data" banner.
- `update_directory` refuses to list someone without a phone number on their profile.
- Released 2026-10-24: the user ran the migration in the SQL editor (verified over REST: anon gets `[]` from `artist_directory`, and is refused `update_directory`), then approved the push. Pushed as `d4fa6c7` and `134e995`. The first commit missed the five new files (see below), and the second added them. That push also published the waiting local commit `8eb6763` (five-hour notice); its migration `202610200001_five_hour_notice.sql` must be applied for the live copy to match.
- With this folder unlistable, `git add <new file>` and `git status` don't see untracked files. Run git from outside with `GIT_DIR=…/.git GIT_WORK_TREE=…`, stage new files with `git update-index --add -- <paths>`, and check `git show --stat HEAD` before pushing.
- 2026-10-24: macOS blocked listing this folder and `~/Documents` for the terminal (file reads still worked), so `npm` and `git` failed here; tests ran from a scratchpad copy (33/33 pass, check passes). Not click-tested in a browser.

## Directory areas (constituencies) (2026-10-25)

- Listings can name an optional area, meaning one of the 290 IEBC constituencies, such as Westlands (Nairobi) or Thika Town (Kiambu). The list lives in `AREAS` in `assets/js/directory-data.js`. The sign-up and dashboard listing form has an "Area (constituency), optional" select that refills when the county changes. Cards show "Area · County".
- Map: tapping a county zooms in close (1.3× its bounding box) and loads `assets/data/areas/<county slug>.json` (47 files, 596 KB total, about 5–19 KB each, fetched only when that county is opened). Its constituencies are drawn over it and shaded on their own square-root scale. Names are only drawn where they fit inside their area without touching another label, biggest areas first (Nairobi shows 7 of 17). The rest can still be tapped, have a hover title, and are in the Area dropdown. Tapping an area zooms further, and the corner button then reads "Back to <county>". Outlines come from geoBoundaries KEN ADM2 (IEBC, CC BY 3.0 IGO), credited in the footer.
- Migration `supabase/migrations/202610250001_directory_areas.sql` adds `profiles.area` (text, default '', max 60), reads `area` from signup metadata when consent is given, replaces `update_directory` with a 4-argument version (`p_area` defaults to ''), and adds `area` to `artist_directory()`. The server only checks length, not that the area belongs to the county; the form only offers that county's areas. **Run it before pushing:** the new dashboard form calls `update_directory` with `p_area`, which fails against the live 3-argument function.
- Tests: the directory subtest in `tests/database.test.mjs` covers area at sign-up, saving, clearing on withdrawal and the length limit (33/33 pass). Clicked through with `?demo` in headless Chrome at 1280 and 390 px wide (Nairobi → Westlands → back, and Kiambu via the dropdown), with no console errors.
- Released 2026-10-25: the user ran the migration in the SQL editor (verified over REST: anon calling the 4-argument `update_directory` with `p_area` gets permission denied rather than function-not-found; `artist_directory` returns `[]`), then approved the push. `santuri-gear-photos/` stays untracked on purpose.

## Night map lights (2026-10-25)

- The directory map is now a "night map": black background, counties in near-black greys (the square-root levels still apply, just very subtly), and one twinkling white light per listed person (after the role filter), drawn by `drawLights` in `assets/js/directory.js`. A light sits at a random point inside the person's area once that county's outlines are loaded, otherwise inside their county (`isPointInFill`, 40 tries, then the bounding-box centre). Positions are seeded from name, phone, county and area, so each person's light stays put between visits and filter changes.
- Busier counties twinkle faster (4.2 s for the quietest, down to 1.4 s for the busiest, square-root scaled). Lights are zero-length paths with round caps and a non-scaling 4 px stroke, so they keep the same size on screen while the map zooms. Above 400 people, every Nth person gets a light and the legend says "Each light is about N people". With reduced motion, the lights stay still.
- Layer order inside the SVG: counties, area fills, lights, area labels (labels were moved out of the `.map-areas` group so they sit above the lights).

## Artist listing page (2026-10-25)

- Bug: the user tried to list themselves from the dashboard and "nothing happened". Their profile had no phone number, so `update_directory` refused the listing with "Add your phone number…". That message went to `#notice` at the top of the dashboard, out of view of the form at the bottom.
- Fixes: `run()` in `account.js` now scrolls `#notice` into view whenever an action fails, on every account page. The listing moved to its own page, `listing.html` (`data-page="listing"`, "Artist listing" in the sidebar of all account pages, `renderListing()`). Its form puts the phone number bookers will call inside the listing fieldset (`directoryFields(profile,true)`), and it is required while the box is ticked. Saving calls `update_profile` first when the phone changed, then `update_directory`. A live preview shows the public card. The dashboard now only shows a one-line summary with an Edit listing / Get listed button.
- The public card markup (`artistCard`, `telLink`, `whatsappLink`) moved to `assets/js/directory-data.js` so the directory and the preview share it. The directory's "Get listed" button and empty-state link go to `listing.html`; signed-out visitors get the sign-in/create-account form there and come back to it afterwards. `privacy.html#directory` now names the Artist listing page and mentions the optional area.
- Checked with a stand-in Supabase client in a scratch copy (signed-in member with no phone, same phone rule as the database): saving without a phone shows the error in view; with a phone it calls `update_profile` then `update_directory` and shows "You are listed". The dashboard summary was checked too. No migration needed.

## Listing contacts instead of phone numbers; map dots on white (2026-10-25)

- User decision: listings show only the contacts each artist chooses, from Instagram, website and email. **Phone numbers are not published for now.** Members still give a phone at sign-up for bookings. At least one contact is needed to be listed, and only filled-in ones appear on the card.
- Migration `supabase/migrations/202610250002_directory_contacts.sql` adds `profiles.directory_instagram` (handle without @, `[A-Za-z0-9._]{1,30}`), `directory_website` (http(s) only, max 200 chars, so no `javascript:` links) and `directory_email` (lowercased), each with a check constraint. It also adds `private.directory_contact(kind,value)`, which returns the cleaned value or '' when it isn't valid; the sign-up trigger uses it so a bad contact is dropped rather than failing sign-up. `update_directory` gains `p_instagram`, `p_website` and `p_email` (all default ''), drops the phone requirement, raises a specific message for each malformed contact and when none is given, and clears contacts on withdrawal. `artist_directory()` now returns `instagram`, `website` and `email` instead of `phone`, and only lists people with at least one contact. **Run it before pushing:** the new pages call the 7-argument `update_directory` and expect the new `artist_directory` columns.
- Form (sign-up opt-in and `listing.html`): "How bookers can reach you" with Instagram username, Website (plain text field, so "example.com" isn't blocked by the browser; `https://` is added) and Email for bookings (prefilled with the account email on the listing page until first listed). `cleanContacts()` in `directory-data.js` turns pasted Instagram links into handles. Sign-up metadata keys are `instagram`, `website` and `contact_email`. The listing page no longer touches the profile phone. The privacy text was updated to match.
- `artistCard` shows "Instagram @handle ↗", the website's host name ↗ and "Email address" (mailto) as buttons; the first is the solid one.
- Map inverted per the user: white background, very light grey county shading, black twinkling dots, black labels with a white halo. The legend says "Each dot is one person."
- Tests: the directory subtest covers contact cleaning at sign-up (including a dropped `javascript:` website), each validation error, the at-least-one rule, listing without a phone, no `phone` in `artist_directory`, and contacts cleared on withdrawal (33/33 pass). Checked in headless Chrome with a stand-in client.
- Released 2026-10-25 together with the night map and the listing page: the user ran `202610250002_directory_contacts.sql` in the SQL editor (verified over REST: anon gets permission denied from the 7-argument `update_directory`; `artist_directory?select=instagram,website,email` returns `[]`, and `select=phone` fails with 42703), then approved the push.

## Listing name (2026-10-25)

- Why: people sign up with legal names, but their artist names often differ. The listing form (sign-up opt-in and `listing.html`) now has an optional "Name on your listing" (`directory_name`, at most 80 characters, trimmed). The placeholder shows the account name. The preview, the listing status line and the dashboard summary ("Listed as …") use it. Sign-up metadata key: `directory_name`.
- Migration `supabase/migrations/202610250003_directory_name.sql` adds `profiles.directory_name`, reads it at sign-up, replaces `update_directory` with an 8-argument version (`p_name` last with default '', so the live 7-argument calls keep working between migration and push), and makes `artist_directory().full_name` return the listing name when set, otherwise the account name. **Only one name is ever returned**, so a legal name is not exposed next to a stage name. A listing needs a listing name or an account name. Withdrawing clears the listing name. The column keeps the name `full_name` so the live page doesn't break when the migration runs first.
- Tests: the directory subtest covers the name at sign-up (trimmed), the 80-character limit, the directory showing "MC Dan" instead of "Dan", and the name cleared on withdrawal (33/33 pass). Checked in headless Chrome with a stand-in client.
- Released 2026-10-25: the user ran `202610250003_directory_name.sql` (verified over REST: anon gets permission denied from the 8-argument `update_directory` with `p_name`; the one live listing still returns a name), then approved the push.

## Listing photos (2026-10-25)

- Optional photo on each listing, added on `listing.html` only (sign-up has no session to upload with). `assets/js/photo.js` `squarePhoto()` shrinks it **on the member's device** before upload: centre-cropped square, at most 640 px, WebP at quality 0.8 (JPEG where the browser can't encode WebP, e.g. older Safari), stepping down to 0.65 and then 0.5 if it's over 300 KB. It respects EXIF rotation, and anything over 25 MB or not an image is refused with a message. Test: a 4000×3000, 1.5 MB JPEG became a 47 KB WebP.
- The photo is shrunk as soon as it's chosen (the status line shows the before/after size) and uploaded when the listing is saved (`savePhoto()` in `account.js`): it uploads to `directory-photos/<user id>/<uuid>.webp|jpg` with a one-year cache, links it with `set_directory_photo`, and then deletes the file it replaced. "Remove photo" unlinks and deletes. Leaving the directory deletes the file too. A failed delete only leaves an unused file behind; nothing cleans those up automatically.
- Migration `supabase/migrations/202610250004_directory_photos.sql`: public bucket `directory-photos` (300 KB limit, WebP/JPEG only); storage policies so a member can insert, select and delete only where `split_part(name,'/',1)=auth.uid()` (no update, so files are never overwritten); `profiles.directory_photo` with a strict path check; `set_directory_photo(p_path)`, which only accepts a file that exists in the caller's own folder, or '' to remove; a trigger that clears the photo when `directory_consent_at` becomes null; and `artist_directory()` returning a `photo` path, which `directory.js` turns into a public URL. Either order of migration and push is safe: the picker only appears once `profiles.directory_photo` exists, and older pages ignore the extra column.
- Cards show the photo edge to edge at the top (`.artist-photo`, square, lazy-loaded). Cards without a photo are unchanged.
- Tests: new subtest "listing photos live in each member's own folder…" (folder isolation for insert and delete, someone else's, missing and `../` paths refused, anon refused, photo returned by the directory, cleared on withdrawal); 34/34 pass. The test harness now grants `delete` on its stub `storage.objects`. Checked in headless Chrome with a stand-in client (shrink, preview, upload, replace and delete the old file, remove, non-image error).
- Released 2026-10-25: the user ran `202610250004_directory_photos.sql` (verified over REST: `artist_directory?select=photo` works; anon is refused `set_directory_photo`; an anon upload is refused by row-level security; the public URL for a missing file in `directory-photos` says "Object not found", not "Bucket not found"), then approved the push. Note: anon `GET /storage/v1/bucket/directory-photos` returns 404 even though the bucket exists, so don't use it as a check.

## Radar ripples when zoomed in (2026-10-25)

- Once a county (or area) is open, its dots grow from 4 to 10 px (`.map-lights.is-zoomed`, eased) and each sends out two radar rings half a beat apart (`drawRipples()` in `directory.js`, `.map-ripples circle`, 2.6 s `ripple` keyframes scaling 0.25→1 while fading out). Only the open county's people (or the open area's) get rings, capped at 80 people (160 rings), and the role filter applies. The ring radius is set in map units for the zoom being shown, so it comes out about 88 px across on screen at any zoom (`RIPPLE_PX=44`, raised from 26 at the user's request), and the ring line doesn't scale. The all-Kenya view has no rings. With reduced motion, the rings are hidden and the dots are still bigger. No database change.
- Released 2026-10-25 with the user's approval.

## Landing page sections (2026-10-26)

- `index.html` now has, after the hero: an **explore strip** (`.explore`: Spaces, Membership, Gear rental, Artist directory as numbered tiles jumping to `#spaces`, `#membership`, `#gear` and `#directory`; it matters most on phones, where the header hides every link except Book a space), the existing spaces and "How it works" sections, then three new sections before Visit:
  - **Membership** (`#membership`): Mwanzo 500, Midi 1,500 and Sana 3,000 KES/month tier cards, with benefits taken from `membership.html`, the Free Tier line and a link to compare. These are static: update them with `membership.html` if prices change.
  - **Gear** (`#gear`): up to four live `gear_items` with photos, rentable ones first (price shown only when available, quantity > 0 and price > 0; otherwise "Ask the team"), each linking to `rent-gear.html?item=…` or `gear.html`. The grid stays hidden if nothing loads.
  - **Directory** (`#directory`): a live count ("N people listed across M counties") and the first three of `artist_directory()` (random order, never ranked) drawn with the shared `artistCard`, including photos, plus Browse and Get listed links.
- Script: `assets/js/home.js` (module). Failures are ignored, so the static copy and links remain.
- The Calendly wording was replaced in the static spaces intro and step 02 of "How it works" ("Request a time"; step 03 is now "Get confirmed"). `catalog.js` still overwrites those two lines with its own booking-calendar wording when online booking is configured.
- Checked in headless Chrome at 1280 and 390 px against live public data (4 gear cards, 1 listing), with no horizontal scroll and no console errors.
- Released 2026-10-26 with the user's approval.

## Landing hero: map and "Open next" (2026-10-26)

- User choice (from five options): the Kenya map as the hero, plus a live "Open next at Santuri" list. Headline "Kenya's sound, on the map.", with Book a space and Get listed actions. Text and the open list sit on the left and the map on the right; on phones (≤900 px) everything stacks in one column. The old hero logo was dropped (the header has it).
- Map (`drawMap()` in `assets/js/home.js`): `kenya-counties.js` loads with a dynamic import after the page text, so the ~30 KB gzipped outlines don't hold up the first paint. One twinkling dot per listed person (capped at 400, as on the directory), and a hollow square for Santuri at The Mall, Westlands, with a radar ring. `SANTURI=[1446,3349]` was fitted from Nairobi county's outline against its longitude and latitude bounds; the outline file records no projection. The square is drawn under the dots so artists in Westlands stay visible. The whole map links to `directory.html`. If the directory fails to load, the map is still drawn without dots.
- Dot placement was moved to `assets/js/map-dots.js` (`seeded`, `spotIn`, `twinkle`, `dot`), shared by `directory.js` and `home.js`, so a person's dot is in the same place on both maps.
- "Open next": new public `next_open_times()` (`supabase/migrations/202610260001_next_open_times.sql`) returns, for each active bookable space, only its next free start within 7 days at its minimum length (slug, name, starts_at, minutes), using `private.slot_ok`; the scan stops at the first free slot. It's shown in Nairobi time as Today, Tomorrow or a weekday, and each row links to `book.html?space=<slug>`. If nothing is free all week, it shows "Fully booked this week · Ask the team". Before the migration runs, the static "See spaces" row stays, so either order of migration and push is safe.
- Quick facts: `#fact-rooms` is set by `catalog.js` (room count; it no longer writes the hourly rate), and `#fact-people` and `#fact-counties` by `home.js` once listings load. Before that they show the old static "1,000 KES per hour" and "01 Nairobi location".
- Tests: "landing page sees only each room's next free time" (anon sees one row per bookable room with only those four columns, each time passes `slot_ok`, and blocking a room's next hour moves it later); 35/35 pass. Checked in headless Chrome at 1440 and 390 px against live public data, with `next_open_times` stubbed with made-up times (it wasn't live yet). No horizontal scroll and no console errors.
- Released 2026-10-26: the user ran `202610260001_next_open_times.sql`. Verified over REST as anon: 4 rows with only slug, name, starts_at and minutes (DJ Practice Room and Classroom free from 14:30 that day with 2 h notice; Workstation and Studio the next mornings with 5 h notice).

## Booking steps moved to the Spaces page (2026-10-26)

- At the user's request, the "From idea to room in three steps" section (`.how-section#how`) was removed from `index.html` and placed in `spaces.html`, before the house rules. The landing page now runs hero › explore › spaces › membership › gear › directory › visit. The "How it works" links in the landing header and footer and in `nura-jck.html` now go to `spaces.html#how` (on `spaces.html` itself, `#how`). `catalog.js` still rewrites step two's wording, now on the Spaces page. The gear and directory pages keep their own step sections.
- Released 2026-10-26 with the user's approval.

## Hero map tour (2026-10-26)

- `tour()` in `assets/js/home.js`: 2.5 s after the map draws, it picks a random listed person (so busier counties come up more often), glides the viewBox to their county over 3.2 s (slowed from 1.8 s at the user's request) (cubic ease, framed at 1.6× the county's bounds, at least 6% of Kenya's width, at the map's own aspect ratio), shows a "County · N artists" label (`.hero-map-now`), enlarges the dots (`.map-lights.is-zoomed`), holds 4 s, glides back out to all of Kenya, then rests 4–8 s.
- It waits while the map is off screen (IntersectionObserver), the tab is hidden, or the pointer is over the map, so people can read it and phones don't burn battery. It doesn't run with reduced motion or when nobody is listed.
- The Santuri square and ring are resized every frame by `place(view)`, so they stay 13 px and 60 px on screen at any zoom (also on window resize).
- Hero dots are placed by county only (no constituency outlines on the landing page), so a listing with an area may sit elsewhere in its county on the hero than on the directory map.
- Checked in headless Chrome against live data: 1× → 10.4× on Nairobi and back, marker sizes constant, holds under the pointer, stays still with reduced motion, no console errors.
- Released 2026-10-26 with the user's approval.
- The hero map has a thin border (`--line`, 1px) with a little padding; the tour label sits inside it.

## Hero tour: slower, framed, and a global moment (2026-10-26)

- Glides now take 3.2 s, and the world dive takes 5.6 s. All glides change the view's width geometrically (log-scale zoom), and the centre moves in step with the zoom, so a world-to-county dive looks as steady as a short one.
- Once in a while (35% of cycles, never the first), the tour pulls out to the world centred on Africa (lon 20°E, lat 8°N, 112° of longitude across: Africa, Europe and the Middle East in the portrait frame), labelled "Kenya · N artists". Kenya turns solid black with white dots (`svg.is-global`), and the Santuri square fades out (its ring stays). After 3 s it dives straight into an artist's county, and the world layer fades out (`svg.show-world`).
- World coastlines: `assets/data/world.json` (16.5 KB, 6.3 KB gzipped), fetched only the first time the tour goes global and drawn under the counties as `.map-world`. It is built by `scripts/world-outline.mjs` from world-atlas@2.0.2 `land-110m.json` (Natural Earth, public domain; the package is ISC), cropped to lon −60…100 and lat −70…85, rounded to 0.1°, with specks under 0.4 square degrees dropped, and split where outlines cross the 180° meridian (otherwise Fiji drew a line right round the map). It uses the Kenya map's fitted projection, plate carrée at 500.2 units per degree (`x=(lon−33.909)·500.2`, `y=(5.416−lat)·500.2`); Kenya's outline lines up with the coastline.
- The landing footer now credits the map data: geoBoundaries (CC BY 4.0, which requires attribution) and Natural Earth.
- Checked in headless Chrome with `Math.random` pinned so the second cycle went global: 1× → 0.07× (world) → 10.4× (Nairobi), ring constant at 60 px, no console errors.
- Released 2026-10-26 with the user's approval.
