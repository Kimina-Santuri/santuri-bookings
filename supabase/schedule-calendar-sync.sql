-- Run only in the connected Supabase project after deploying calendar-sync.
-- Set the two placeholders privately in the SQL Editor, not in Git.
create extension if not exists pg_cron;
create extension if not exists pg_net;
select vault.create_secret('https://gudbkpwxszdtirewawep.supabase.co/functions/v1/calendar-sync', 'santuri_calendar_sync_url');
select vault.create_secret('REPLACE_WITH_A_RANDOM_32_BYTE_SECRET', 'santuri_calendar_sync_secret');
select cron.schedule(
 'santuri-calendar-sync',
 '*/5 * * * *',
 $$ select net.http_post(
  url := (select decrypted_secret from vault.decrypted_secrets where name='santuri_calendar_sync_url'),
  headers := jsonb_build_object('Content-Type','application/json','x-sync-secret',(select decrypted_secret from vault.decrypted_secrets where name='santuri_calendar_sync_secret')),
  body := '{}'::jsonb,
  timeout_milliseconds := 180000
 ); $$
);
