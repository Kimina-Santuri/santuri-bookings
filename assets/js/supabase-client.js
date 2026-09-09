let clientPromise;
export function configured() {
  const c = window.SANTURI_CONFIG;
  return Boolean(c?.accountsEnabled && /^https:\/\/[a-z0-9-]+\.supabase\.co\/?$/.test(c.supabaseUrl) && c.supabasePublishableKey && !c.supabasePublishableKey.startsWith('sb_secret_'));
}
export async function getClient() {
  if (!configured()) return null;
  if (!clientPromise) clientPromise = import('../vendor/supabase.js').then(({createClient}) => createClient(window.SANTURI_CONFIG.supabaseUrl,window.SANTURI_CONFIG.supabasePublishableKey,{auth:{flowType:'pkce',detectSessionInUrl:true,persistSession:true,autoRefreshToken:true}}));
  return clientPromise;
}
export async function result(query) { const {data,error} = await query; if(error) throw error; return data; }
