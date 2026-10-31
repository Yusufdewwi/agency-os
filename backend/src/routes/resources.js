import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { paginationSchema, safeRecord, uuid } from '../schemas/common.js';

const router = Router();
router.use(requireAuth);

// Only these tables are exposed. Supabase RLS is the authorization boundary.
// Never add a table here until its RLS policies and permissions have been reviewed.
const resources = new Set([
  'clients', 'leads', 'activities', 'projects', 'tasks', 'campaigns',
  'content_items', 'affiliates', 'commission_rules', 'commission_entries',
  'invoices', 'expenses', 'wallet_accounts', 'ledger_entries',
  'payout_requests', 'meetings', 'meeting_participants', 'internal_messages',
  'candidates', 'job_openings', 'documents', 'notifications'
]);

function tableOr404(name, res) {
  if (!resources.has(name)) {
    res.status(404).json({ error: { code: 'RESOURCE_NOT_FOUND', message: 'Unknown resource.' } });
    return false;
  }
  return true;
}

router.get('/:resource', async (req, res, next) => {
  try {
    const { resource } = req.params;
    if (!tableOr404(resource, res)) return;
    const parsed = paginationSchema.safeParse(req.query);
    if (!parsed.success) return res.status(422).json({ error: { code: 'INVALID_QUERY', details: parsed.error.flatten() } });
    const { page, pageSize, search } = parsed.data;
    const from = (page - 1) * pageSize;
    let query = req.auth.supabase.from(resource).select('*', { count: 'exact' }).range(from, from + pageSize - 1).order('created_at', { ascending: false });
    if (search) {
      // Search is intentionally limited to a common text column. Resource-specific
      // advanced filters should be implemented as dedicated endpoints.
      const searchColumn = { clients: 'name', leads: 'name', projects: 'name', campaigns: 'name', content_items: 'title', affiliates: 'name', candidates: 'full_name', job_openings: 'title', documents: 'name' }[resource];
      if (searchColumn) query = query.ilike(searchColumn, `%${search.replace(/[%_,]/g, '')}%`);
    }
    const { data, error, count } = await query;
    if (error) throw error;
    res.json({ data, pagination: { page, pageSize, total: count ?? data.length } });
  } catch (e) { next(e); }
});

router.post('/:resource', async (req, res, next) => {
  try {
    const { resource } = req.params;
    if (!tableOr404(resource, res)) return;
    const parsed = safeRecord.safeParse(req.body);
    if (!parsed.success) return res.status(422).json({ error: { code: 'INVALID_BODY', details: parsed.error.flatten() } });
    const { data, error } = await req.auth.supabase.from(resource).insert(parsed.data).select('*').single();
    if (error) throw error;
    res.status(201).json({ data });
  } catch (e) { next(e); }
});

router.patch('/:resource/:id', async (req, res, next) => {
  try {
    const { resource, id } = req.params;
    if (!tableOr404(resource, res)) return;
    if (!uuid.safeParse(id).success) return res.status(400).json({ error: { code: 'INVALID_ID', message: 'A valid UUID is required.' } });
    const parsed = safeRecord.safeParse(req.body);
    if (!parsed.success) return res.status(422).json({ error: { code: 'INVALID_BODY', details: parsed.error.flatten() } });
    const { data, error } = await req.auth.supabase.from(resource).update(parsed.data).eq('id', id).select('*').single();
    if (error) throw error;
    res.json({ data });
  } catch (e) { next(e); }
});

router.delete('/:resource/:id', async (req, res, next) => {
  try {
    const { resource, id } = req.params;
    if (!tableOr404(resource, res)) return;
    if (!uuid.safeParse(id).success) return res.status(400).json({ error: { code: 'INVALID_ID', message: 'A valid UUID is required.' } });
    const { error } = await req.auth.supabase.from(resource).delete().eq('id', id);
    if (error) throw error;
    res.status(204).end();
  } catch (e) { next(e); }
});

export default router;
