import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

router.get('/me', requireAuth, async (req, res, next) => {
  try {
    const { data: memberships, error } = await req.auth.supabase
      .from('organization_members')
      .select('id, organization_id, department_id, role_id, status, organizations(id,name,slug), departments(id,name), roles(id,name,permissions)')
      .eq('user_id', req.auth.user.id)
      .eq('status', 'active');
    if (error) throw error;
    res.json({
      data: {
        user: {
          id: req.auth.user.id,
          email: req.auth.user.email,
          metadata: req.auth.user.user_metadata || {}
        },
        memberships
      }
    });
  } catch (e) { next(e); }
});

export default router;
