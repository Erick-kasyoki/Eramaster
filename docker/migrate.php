<?php
// Runs schema.sql against the configured database on every boot. schema.sql is idempotent
// (CREATE TABLE IF NOT EXISTS / ADD COLUMN IF NOT EXISTS), so this is safe to repeat.
// Retries for ~60 s so a cold-starting Postgres service doesn't fail the deploy.
function envv($n, $d = null) { $v = getenv($n); return ($v === false || $v === '') ? $d : $v; }

$url = envv('DATABASE_URL') ?? envv('DATABASE_PRIVATE_URL');
if ($url && ($p = parse_url($url)) && !empty($p['host'])) {
    $host = $p['host']; $port = $p['port'] ?? 5432; $name = ltrim(rawurldecode($p['path'] ?? ''), '/');
    $user = rawurldecode($p['user'] ?? ''); $pass = rawurldecode($p['pass'] ?? '');
} else {
    $host = envv('PGHOST'); $port = envv('PGPORT', '5432'); $name = envv('PGDATABASE');
    $user = envv('PGUSER'); $pass = envv('PGPASSWORD', '');
}
if (!$host || !$name || !$user) {
    fwrite(STDERR, "[migrate] No database configured. Add a PostgreSQL service in Railway and reference its DATABASE_URL in this service's variables.\n");
    exit(1);
}

$pdo = null;
for ($i = 1; $i <= 30; $i++) {
    try {
        $pdo = new PDO("pgsql:host=$host;port=$port;dbname=$name;connect_timeout=5", $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        break;
    } catch (PDOException $e) {
        fwrite(STDERR, "[migrate] database not ready ($i/30): " . $e->getMessage() . "\n");
        sleep(2);
    }
}
if (!$pdo) { fwrite(STDERR, "[migrate] giving up - could not reach the database.\n"); exit(1); }

$file = is_file(__DIR__ . '/schema.sql') ? __DIR__ . '/schema.sql' : dirname(__DIR__) . '/schema.sql';   // image: next to this script; repo: one level up
$sql = file_get_contents($file);
try {
    $pdo->exec("SET lock_timeout = '30s'");
    $pdo->exec($sql);     // simple-query protocol: multiple statements in one call are fine
    echo "[migrate] schema.sql applied OK\n";
} catch (PDOException $e) {
    fwrite(STDERR, "[migrate] schema.sql FAILED: " . $e->getMessage() . "\n");
    exit(1);
}
