<?php
// Emergency Super-Administrator password reset for Railway (the web page api/recover.php is local-only and
// therefore unreachable on a hosted server).  Run it from your own terminal against the live service:
//
//   railway ssh            (then, inside the container:)
//   php /opt/eramaster/reset-admin.php admin@school.org 'NewPassw0rd'
//
// It also clears that account's two-factor setting and active sessions, exactly like recover.php does.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require is_file('/var/www/html/api/config.php') ? '/var/www/html/api/config.php' : dirname(__DIR__) . '/api/config.php';
[$_, $email, $pw] = array_pad($argv, 3, '');
$email = strtolower(trim($email));
if ($email === '' || $pw === '') { fwrite(STDERR, "usage: php reset-admin.php <email> <new-password>\n"); exit(2); }
if ($p = passwordProblem($pw)) { fwrite(STDERR, $p . "\n"); exit(2); }
$st = $pdo->prepare('SELECT id, name FROM staff_accounts WHERE LOWER(email) = ? AND is_admin = true LIMIT 1');
$st->execute([$email]);
$u = $st->fetch();
if (!$u) { fwrite(STDERR, "No Super Administrator with that email.\n"); exit(1); }
$pdo->prepare('UPDATE staff_accounts SET password_hash = ?, must_change_password = false, is_active = true, access_expires_at = NULL, totp_enabled = false, totp_secret = NULL WHERE id = ?')
    ->execute([password_hash($pw, PASSWORD_DEFAULT), $u['id']]);
try { $pdo->prepare('DELETE FROM active_sessions WHERE user_id = ?')->execute([$u['id']]); } catch (Throwable $e) {}
echo "Password reset for {$u['name']}.\n";
