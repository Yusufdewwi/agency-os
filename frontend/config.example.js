/**
 * Public browser configuration only.
 * Supabase URL + publishable/anon key may be used by a browser client.
 * Never put service-role keys, OAuth client secrets, or payment keys here.
 */
window.AGENCY_OS_CONFIG = {
  API_BASE_URL: window.location.origin,
  SUPABASE_URL: "REPLACE_WITH_SUPABASE_PROJECT_URL",
  SUPABASE_PUBLISHABLE_KEY: "REPLACE_WITH_SUPABASE_PUBLISHABLE_OR_ANON_KEY"
};
