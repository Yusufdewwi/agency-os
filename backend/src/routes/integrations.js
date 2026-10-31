import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';

const router = Router();
router.use(requireAuth);

// OAuth provider endpoints are intentionally not enabled until callback URLs,
// scopes, encryption key, and provider credentials are supplied.
router.get('/', async (req, res, next) => {
  try {
    const { data, error } = await req.auth.supabase
      .from('integration_connections')
      .select('id, provider, status, account_email, connected_at, last_synced_at, created_at');
    if (error) throw error;
    res.json({ data, setup: { googleOAuth: Boolean(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET) } });
  } catch (e) { next(e); }
});

router.post('/:provider/connect', (req, res) => {
  res.status(501).json({
    error: {
      code: 'PROVIDER_SETUP_REQUIRED',
      message: `OAuth for ${req.params.provider} is not enabled. Add the provider credentials, callback URL, scopes and token encryption before activation.`
    },
    requiredConfiguration: ['provider client id', 'provider client secret', 'redirect/callback URL', 'approved OAuth scopes']
  });
});

export default router;
