-- Run only in the connected Supabase project after deploying email-notifications.
-- Replace the two placeholders privately in the SQL Editor. Do not commit secrets.
create extension if not exists pg_cron;
create extension if not exists pg_net;
select vault.create_secret('https://YOUR_PROJECT_REF.supabase.co/functions/v1/email-notifications', 'santuri_email_notifications_url');
select vault.create_secret('REPLACE_WITH_A_RANDOM_32_BYTE_SECRET', 'santuri_email_notifications_secret');
select cron.schedule(
 'santuri-email-notifications',
 '* * * * *',
 $$ select net.http_post(
  url := (select decrypted_secret from vault.decrypted_secrets where name='santuri_email_notifications_url'),
  headers := jsonb_build_object('Content-Type','application/json','x-email-secret',(select decrypted_secret from vault.decrypted_secrets where name='santuri_email_notifications_secret')),
  body := '{}'::jsonb,
  timeout_milliseconds := 120000
 ); $$
);
