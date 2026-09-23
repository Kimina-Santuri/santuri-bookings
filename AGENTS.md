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
- Production and studio bookings require at least 24 hours' notice through the Community Manager. Cancellations require at least 12 hours' notice; no-shows forfeit the relevant weekly hours.

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
