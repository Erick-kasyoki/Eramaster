#!/bin/bash
# EraMaster container boot: persistent storage -> database schema -> Apache on $PORT.
set -e
APP=/var/www/html

# ---- 1. Persistent storage -------------------------------------------------------------
# Railway mounts a Volume at the path in RAILWAY_VOLUME_MOUNT_PATH (e.g. /data). Uploaded files (school logo,
# homepage slideshow) and PHP sessions are kept there so they survive redeploys.  Without a volume they still
# work but are wiped on every deploy.
DATA="${DATA_DIR:-${RAILWAY_VOLUME_MOUNT_PATH:-}}"
if [ -n "$DATA" ] && [ -d "$DATA" ]; then
  echo "[eramaster] persistent storage: $DATA"
  mkdir -p "$DATA/uploads/slideshow" "$DATA/uploads/logo" "$DATA/sessions"
  # keep the shipped uploads/.htaccess (blocks script execution) inside the volume copy
  cp -f "$APP/uploads/.htaccess" "$DATA/uploads/.htaccess" 2>/dev/null || true
  # first run only: seed the volume with any files shipped inside the image
  cp -rn "$APP/uploads/." "$DATA/uploads/" 2>/dev/null || true
  rm -rf "$APP/uploads"
  ln -s "$DATA/uploads" "$APP/uploads"
  chown -R www-data:www-data "$DATA"
  SESS="$DATA/sessions"
else
  echo "[eramaster] WARNING: no volume mounted - uploads and sign-in sessions will be lost on every redeploy."
  mkdir -p /var/lib/eramaster-sessions "$APP/uploads/slideshow" "$APP/uploads/logo"
  chown -R www-data:www-data /var/lib/eramaster-sessions "$APP/uploads"
  SESS=/var/lib/eramaster-sessions
fi
echo "session.save_path = \"$SESS\"" > /usr/local/etc/php/conf.d/zz-session.ini

# ---- 2. Database schema (idempotent: only adds what is missing, never touches data) -------
if [ "${SKIP_MIGRATE:-0}" != "1" ]; then
  php /opt/eramaster/migrate.php
fi

# ---- 3. Listen on the port Railway gives us -----------------------------------------------
PORT="${PORT:-8080}"
sed -ri "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf
echo "[eramaster] starting Apache on port ${PORT}"
exec "$@"
