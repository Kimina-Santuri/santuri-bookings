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
- NURA JCK runs regular CDJ practice sessions: Fridays in the DJ Practice Room and Saturdays from 11:00–18:00 in the Classroom.
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
5. Classroom and Creative Workstation calendars are now connected and syncing. Configure their confirmed opening schedules in the Staff dashboard and enable online booking only after those hours are agreed.
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
- The homepage space grid includes a clickable NURA x JCK card linking to `nura-jck.html`. Its dedicated page has matching Friday DJ Practice Room and Saturday Classroom booking buttons, with both sessions listed as 11:00–18:00. The buttons open the authenticated booking calendar with the relevant space selected.
- Approved booking events synced to Google Calendar include the booker’s name and space in the event title; pending requests retain a `[Requested]` prefix. This is implemented in migration `202609090005_calendar_booking_names.sql` and the deployed `calendar-sync` function.

## Student access and NURA x JCK release (2026-09-12)

- Staff manually grant/remove Student access in Members. Students receive 480 shared minutes per Nairobi week across all spaces, subject to configured booking availability and approval; hours reset Monday with no carryover. Student access grants no staff privileges or alumni eligibility.
- Migration `202609120001_student_access.sql` has been applied to the connected Supabase project and its API schema refreshed to enable local student testing. Staff access takes priority; Student access uses its own shared pool while assigned, separately from paid-tier allowances.
- NURA x JCK card now uses `assets/images/nura.jpg` and `assets/images/nuralogo.png`.
- The homepage NURA x JCK card is a single keyboard-accessible link to `nura-jck.html`. The dedicated page contains confirmed session details and the Friday DJ / Saturday Classroom booking buttons at the bottom.

- The user approved pushing this complete version to the canonical GitHub `main` branch on 2026-09-12. No separate Sites deployment was requested. Future changes remain local unless approved.
- Verification: all 21 automated tests pass; `npm run check` and `npm run build` pass; all 12 pages respond on the local preview. The connected API resolves student functions and rejects unauthenticated access.
