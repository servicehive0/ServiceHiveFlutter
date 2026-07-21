// ─── Supabase credentials ─────────────────────────────────────────────────────
const kSupabaseUrl     = 'https://wkdtptmgmxasmpqtawog.supabase.co';
const kSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndrZHRwdG1nbXhhc21wcXRhd29nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2NzIyMTYsImV4cCI6MjA5NjI0ODIxNn0.mg9G26letrLfF2WPxoVeaJGtsUTdi6Y4yvSNM5iy_WI';

// ─── Groq (AI features) ───────────────────────────────────────────────────────
// Single source of truth for the Groq key — was previously duplicated as a
// literal in 8 separate screen files, making rotation error-prone.
// NOTE: this is still compiled into the client binary/web bundle, same as
// before; the key is not truly secret until AI calls go through a server-side
// proxy (e.g. a Supabase Edge Function) instead of calling Groq directly from
// the client. Rotate this key if it has ever been exposed publicly.
const kGroqApiKey = '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';

// ─── ML service (Service-Hive-ML, deployed on Vercel) ─────────────────────────
const kMlServiceUrl = 'https://service-hive-ml.vercel.app';
