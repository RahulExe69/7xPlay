# 7xPlay Supabase configuration

Project ref: `xrupzibcjajgdemseeij`

7xPlay now reads public runtime settings from the Supabase REST endpoint `/rest/v1/app_config`. The Android client uses only the project URL and publishable key; never put a Supabase secret or service-role key in the app.

## Runtime configuration table

The `public.app_config` table is public-read-only for the `anon` and `authenticated` roles. Row Level Security is enabled. Mobile clients must not write configuration. Manage rows through the Supabase dashboard/SQL editor or a trusted server-side process.

Each row has:
- `key`: setting name (primary key)
- `value`: JSONB value
- `description`: optional explanation
- `updated_at`: last update timestamp

Useful keys include:
- `laravel_api_url`: optional Laravel API base URL; the app appends `/api/v1/` when needed.
- `enable_stream`, `enable_download`, `enable_live_tv`: feature flags.
- `app_logo_url`, `flixquest_api_url_v2`, `flixquest_api_instances`, `tmdb_proxy`: runtime endpoints and branding, if required.
- `latest_version`, `latest_build_number`, `min_build_number`, `forced_update`, `app_download_url`, `change_log`: update metadata.

Only add values that have been audited and are safe to expose publicly. Do not store passwords, private API tokens, service-role keys, or other secrets in this table. A publishable client key is not a security boundary; RLS is.

## Fallback behaviour

If Supabase is offline, unreachable, or the table has no applicable rows, 7xPlay keeps its cached settings and existing bundled/Laravel fallback. The initial table is intentionally empty: the original FlixQuest project's live Firebase settings were not copied blindly because we do not own or control that project.

## Remaining migration work

This is the first stage, not a claim that all Firebase services have been removed. Firebase still has other call sites for legacy sign-in migration, crash reporting, notifications, and analytics. Those must be migrated or removed independently with regression tests before deleting Firebase packages or Android Google Services configuration.
