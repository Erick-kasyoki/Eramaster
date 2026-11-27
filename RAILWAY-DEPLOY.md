# Deploying EraMaster on Railway (no Netlify)

Netlify only hosts static files. EraMaster is PHP + PostgreSQL, so it needs a real server: Railway runs it as a
Docker container (`Dockerfile`) next to a managed PostgreSQL database.

## What was changed for Railway
| File | Purpose |
|---|---|
| `Dockerfile` | PHP 8.3 + Apache with `pdo_pgsql`, `zip`, `mbstring`; enables `rewrite`, `headers`, `remoteip` |
| `docker/apache-eramaster.conf` | Honours the app's `.htaccess` files; real visitor IP and HTTPS detected behind Railway's proxy |
| `docker/php-eramaster.ini` | 64 MB uploads (Data Import), logs to stderr |
| `docker/entrypoint.sh` | Links uploads + sessions to the Volume, runs the DB migration, listens on Railway's `$PORT` |
| `docker/migrate.php` | Applies `schema.sql` on every boot (idempotent - never touches data) |
| `docker/reset-admin.php` | Emergency admin-password reset (the web `recover.php` page is local-only by design) |
| `railway.json` | Tells Railway to build the Dockerfile + health check |
| `api/config.php` | Reads `DATABASE_URL` / env vars. **The hard-coded default DB password was removed.** |

## Steps
1. **Push to GitHub.** Create a private repo and push this folder (the `.git` history is included).
2. **Railway -> New Project -> Deploy from GitHub repo** -> pick the repo. It detects `railway.json`/`Dockerfile`.
3. **Add the database:** in the project click **+ New -> Database -> PostgreSQL**.
4. **Link them:** open your web service -> **Variables** -> add
   `DATABASE_URL` = `${{Postgres.DATABASE_URL}}`   (use the exact name of your Postgres service in `Postgres`).
5. **Add a Volume** (needed so the school logo, slideshow photos and sign-in sessions survive redeploys):
   web service -> **Settings -> Volumes -> Add Volume**, mount path `/data`.
6. **Generate a public URL:** web service -> **Settings -> Networking -> Generate Domain**
   (or add your own domain and the CNAME Railway shows).
7. Open the URL. **Create the first account immediately** - the first sign-up becomes Super Administrator,
   so do not leave a fresh public deployment sitting unclaimed.
8. Optional variables: `APP_DEBUG=true` (only while troubleshooting), `ALLOW_SELF_SIGNUP`, and the `SOCIAL_*`
   keys. If you use social login, set `SOCIAL_REDIRECT_URI=https://YOUR-DOMAIN/api/social.php` and register the
   same URL in each provider's console.

Check **Deployments -> View logs**: you should see `[eramaster] persistent storage: /data`,
`[migrate] schema.sql applied OK`, then Apache starting.

## Moving your existing data from XAMPP
```bash
pg_dump -U postgres -Fc --no-owner --no-privileges greenhill_academy > school.dump
# Railway Postgres -> Connect -> copy the *public* connection URL, then:
pg_restore --no-owner --no-privileges --clean --if-exists -d "<PUBLIC_DATABASE_URL>" school.dump
```
Then copy uploaded files (`uploads/logo`, `uploads/slideshow`) by re-uploading the logo/photos in
Settings (or with `railway ssh` + `scp`-style tools). Everyone signs in again once after the move.

## Operations
* **Locked out of the only admin?** `railway ssh` then
  `php /opt/eramaster/reset-admin.php admin@school.org 'NewPassw0rd9'`
* **Updates:** push to GitHub; Railway rebuilds. The schema migrates itself.
* **Backups:** Railway Postgres -> Backups tab (enable them), or periodic `pg_dump` as above.
* Keep **one replica** (sessions and uploads live on the single Volume).
* Passwords that were in the old `config.php` / zip should be considered exposed - the app now uses Railway's
  generated DB password, so nothing else needs rotating, but do not reuse the old one anywhere.
* HSTS in `.htaccess` is 1 day; raise to `31536000` once you are happy with HTTPS.

## Not verified here
The Docker image itself could not be built in the preparation sandbox (no Docker daemon). The PHP side was
tested against PostgreSQL 16 with a Railway-style `DATABASE_URL` (migration twice, sign-up, login, session,
admin reset). If the first Railway build fails, paste the build log and it is a quick fix.
