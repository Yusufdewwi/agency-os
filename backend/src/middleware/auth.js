import { supabaseForToken } from '../lib/supabase.js';

export async function requireAuth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!token) return res.status(401).json({ error: { code: 'AUTH_REQUIRED', message: 'Bearer token required.' } });

    const supabase = supabaseForToken(token);
    const { data, error } = await supabase.auth.getUser(token);
    if (error || !data?.user) return res.status(401).json({ error: { code: 'INVALID_TOKEN', message: 'Session is invalid or expired.' } });

    req.auth = { user: data.user, token, supabase };
    next();
  } catch (error) {
    next(error);
  }
}
