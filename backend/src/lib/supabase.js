import { createClient } from '@supabase/supabase-js';
import { env } from '../config/env.js';

// Create a user-scoped client from the incoming JWT. RLS remains active.
// The service-role key is deliberately not used by this API.
export function supabaseForToken(accessToken) {
  return createClient(env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${accessToken}` } }
  });
}
