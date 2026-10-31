/*
 * Drop-in API helper for the existing HTML frontend.
 * Replace API_BASE_URL with the deployed backend URL.
 * The Supabase session must be obtained from the frontend Supabase client.
 */
const API_BASE_URL = 'REPLACE_WITH_BACKEND_API_URL';

export function createAgencyApi(getAccessToken) {
  async function request(path, options = {}) {
    const token = await getAccessToken();
    if (!token) throw new Error('Please sign in first.');
    const response = await fetch(`${API_BASE_URL}/api/v1${path}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        ...(options.headers || {})
      }
    });
    if (response.status === 204) return null;
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload?.error?.message || `API error ${response.status}`);
    return payload;
  }
  return {
    me: () => request('/auth/me'),
    list: (resource, params = {}) => request(`/${resource}?${new URLSearchParams(params)}`),
    create: (resource, body) => request(`/${resource}`, { method: 'POST', body: JSON.stringify(body) }),
    update: (resource, id, body) => request(`/${resource}/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
    remove: (resource, id) => request(`/${resource}/${id}`, { method: 'DELETE' }),
    integrations: () => request('/integrations')
  };
}
