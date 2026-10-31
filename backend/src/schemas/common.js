import { z } from 'zod';

export const uuid = z.string().uuid();
export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(25),
  search: z.string().trim().max(120).optional()
});
export const idParams = z.object({ id: uuid });
export const safeRecord = z.record(z.string(), z.unknown()).refine(
  obj => Object.keys(obj).length > 0 && Object.keys(obj).length <= 40,
  'Provide a non-empty record with at most 40 fields.'
);
