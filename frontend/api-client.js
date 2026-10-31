/**
 * Agency OS API client scaffold.
 * The current HTML preview remains unchanged and continues to use its existing
 * browser-local data until its screens are migrated to these authenticated APIs.
 *
 * Never put SUPABASE_SERVICE_ROLE_KEY, Google client secrets, or payment secrets here.
 */
const AGENCY_API_BASE = window.AGENCY_API_BASE || window.location.origin;

export async function apiRequest(path, { token, method = "GET", body } = {}) {
  if (!token) throw new Error("Sign in with Supabase Auth before calling protected APIs.");
  const response = await fetch(`${AGENCY_API_BASE}/api/v1${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body ? { "Content-Type": "application/json" } : {})
    },
    ...(body ? { body: JSON.stringify(body) } : {})
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = payload?.error?.message || `API request failed (${response.status})`;
    throw new Error(message);
  }
  return payload;
}
