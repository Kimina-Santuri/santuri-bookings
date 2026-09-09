# Santuri East Africa Bookings

Framework-free static website with an optional Supabase account and booking system. Existing Calendly bookings continue until the new backend is connected.

## Local development

```sh
npm install
npm run build
npm test
npm run check
npm run dev
```

Open `http://127.0.0.1:8080`. The new pages are `account.html`, `dashboard.html`, `book.html`, `bookings.html`, `admin.html` and `reset-password.html`. Without a configured backend, account operations are disabled and the staff page shows a read-only space preview.

## Backend setup

Follow [docs/SETUP.md](docs/SETUP.md) to configure Supabase, appoint staff, connect the existing email provider and schedule Google Calendar sync. Public connection settings go in `assets/js/config.js`; private keys never belong in the repository.

The database schema, permissions and booking rules are versioned in `supabase/migrations`. Space images use Supabase Storage. Staff edit space descriptions, prices, images and schedules in the dashboard after setup. Existing room data in `assets/js/main.js` remains the unconfigured Calendly fallback.

`npm run build` produces public files in `dist/`; database scripts, source documentation and secrets are excluded. GitHub remains the canonical code repository. Keep work local until a release is explicitly approved; do not update Sites or the custom domain by default.
