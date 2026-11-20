import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env.js';
import { query, withTx } from '../../db/pool.js';
import { AppError, result } from '../../common/errors.js';
import { cleanString, ensure, isEmail, isPresent } from '../../common/validate.js';
import { isValidTimeZone } from '../../common/time.js';
import { audit } from '../../common/audit.js';
import { toUserDto } from '../user/user.mapper.js';
import { createSession, revokeAllSessions, sha256 } from './token.service.js';
import { sendVerificationEmail } from './mail.service.js';

export const LANGUAGES = ['vi', 'en'];
const MAX_VERIFY_ATTEMPTS = 5;
const RESEND_COOLDOWN_MS = 60_000;

const validPassword = (p) => typeof p === 'string' && p.length >= 6 && p.length <= 20;
const normEmail = (e) => e.trim().toLowerCase();

async function createVerification(db, userId, type = 'email_verification') {
  await db.query(
    'UPDATE email_verifications SET used_at = now() WHERE user_id = $1 AND type = $2 AND used_at IS NULL',
    [userId, type],
  );
  const code = crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
  const confirmToken = crypto.randomBytes(32).toString('hex');
  await db.query(
    `INSERT INTO email_verifications (user_id, code_hash, token_hash, type, expires_at)
     VALUES ($1, $2, $3, $4, now() + make_interval(mins => $5))`,
    [userId, sha256(code), sha256(confirmToken), type, env.verificationCodeTtlMinutes],
  );
  return { code, confirmToken };
}

function deliver(user, code) {
  sendVerificationEmail(user.email, user.name, code).catch((err) =>
    console.error(`[mail] gửi OTP tới ${user.email} thất bại: ${err.message}`),
  );
}

/** POST user/ - Đăng ký tài khoản (chưa xác minh). */
export async function register(body = {}) {
  const { username, password, email, name, language, timezone, deviceId } = body;
  ensure(isPresent(username) && isPresent(password) && isPresent(email) && isPresent(name), '00005');
  const cleanUsernameRow = String(username).normalize('NFC').trim();
  ensure(USERNAME_RE.test(cleanUsernameRow), '00029');
  const cleanUsername = cleanUsernameRow;
  ensure(cleanUsername, '00029');
  ensure(isEmail(email), '00026');
  ensure(validPassword(password), '00027');
  const cleanName = cleanString(name, { min: 4, max: 29 });
  ensure(cleanName, '00028');
  const lang = isPresent(language) ? String(language).trim() : 'vi';
  ensure(LANGUAGES.includes(lang), '00079');
  if (isPresent(timezone)) ensure(isValidTimeZone(timezone), '00505');
  const tz = isPresent(timezone) ? timezone : 'Asia/Ho_Chi_Minh';

  const passwordHash = await bcrypt.hash(password, 10);
  let created;
  try {
    created = await withTx(async (db) => {
      const { rows } = await db.query(
        `INSERT INTO users (username, password_hash, name, email, language, timezone, device_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
        [cleanUsername, passwordHash, cleanName, normEmail(email), lang, tz, isPresent(deviceId) ? String(deviceId) : null],
      );
      const user = rows[0];
      const v = await createVerification(db, user.id, 'email_verification');
      await audit(db, { userId: user.id }, 'user.register', 'user', user.id);
      return { user, ...v };
    });
  } catch (err) {
    if (err.code === '23505') {
      if (err.detail && err.detail.includes('username')) throw new AppError('00084');
      if (err.detail && err.detail.includes('email')) throw new AppError('00032');
    }
    throw err;
  }
  deliver(created.user, created.code);
  return result('00035', { user: toUserDto(created.user), confirmToken: created.confirmToken });
}

/** POST user/send-verification-code/ - Gửi lại mã OTP. */
export async function sendVerificationCode(body = {}) {
  ensure(isPresent(body.email), '00005');
  ensure(isEmail(body.email), '00026');
  const { rows } = await query('SELECT * FROM users WHERE lower(email) = $1', [normEmail(body.email)]);
  const user = rows[0];
  ensure(user, '00036');
  if (user.email_verified_at) return result('00058', { alreadyVerified: true });

  const last = await query(
    'SELECT created_at FROM email_verifications WHERE user_id = $1 AND type = $2 ORDER BY id DESC LIMIT 1',
    [user.id, 'email_verification'],
  );
  if (last.rows[0] && Date.now() - new Date(last.rows[0].created_at).getTime() < RESEND_COOLDOWN_MS) {
    throw new AppError('00024');
  }
  const v = await withTx((db) => createVerification(db, user.id, 'email_verification'));
  deliver(user, v.code);
  return result('00048', { confirmToken: v.confirmToken });
}

/** POST user/verify-email/ - Xác minh bằng mã OTP + confirmToken. */
export async function verifyEmail(body = {}) {
  ensure(isPresent(body.token), '00055');
  ensure(isPresent(body.code), '00053');
  // Tăng số lần thử một cách nguyên tử trước khi so mã => chống dò mã song song
  const { rows } = await query(
    `UPDATE email_verifications SET attempt_count = attempt_count + 1
      WHERE token_hash = $1 AND type = 'email_verification' AND used_at IS NULL AND expires_at > now() AND attempt_count < $2
      RETURNING *`,
    [sha256(String(body.token)), MAX_VERIFY_ATTEMPTS],
  );
  const v = rows[0];
  ensure(v, '00055');
  const ok = crypto.timingSafeEqual(Buffer.from(sha256(String(body.code).trim())), Buffer.from(v.code_hash));
  ensure(ok, '00054', { attemptsLeft: MAX_VERIFY_ATTEMPTS - v.attempt_count });

  return withTx(async (db) => {
    const verified = await db.query(
      'UPDATE email_verifications SET verified_at = now() WHERE id = $1 AND verified_at IS NULL AND used_at IS NULL RETURNING id',
      [v.id],
    );
    ensure(verified.rowCount, '00055');
    const u = await db.query(
      'UPDATE users SET email_verified_at = COALESCE(email_verified_at, now()) WHERE id = $1 RETURNING *',
      [v.user_id],
    );
    await audit(db, { userId: v.user_id }, 'user.verify_email', 'user', v.user_id);
    return result('00058', { user: toUserDto(u.rows[0]) });
  });
}

/** POST user/send-password-reset-code/ - Gửi lại mã đặt lại mật khẩu. */
export async function sendPasswordResetCode(body = {}) {
  ensure(isPresent(body.email), '00005');
  ensure(isEmail(body.email), '00026');
  const { rows } = await query('SELECT * FROM users WHERE lower(email) = $1', [normEmail(body.email)]);
  const user = rows[0];
  ensure(user, '00036');

  const last = await query('SELECT created_at FROM email_verifications WHERE user_id = $1 AND type = $2 ORDER BY id DESC LIMIT 1', [
    user.id,
    'password_reset',
  ]);
  if (last.rows[0] && Date.now() - new Date(last.rows[0].created_at).getTime() < RESEND_COOLDOWN_MS) {
    throw new AppError('00055');
  }
  const v = await withTx((db) => createVerification(db, user.id, 'password_reset'));
  deliver(user, v.code);
  return result('00048', { confirmToken: v.confirmToken });
}

/** POST user/verify-password-reset-code/ - Xác minh mã OTP đặt lại mật khẩu. */
export async function verifyPasswordResetCode(body = {}) {
  ensure(isPresent(body.token), '00055');
  ensure(isPresent(body.code), '00053');
  const { rows } = await query(
    `UPDATE email_verifications SET attempt_count = attempt_count + 1
      WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now() AND attempt_count < $2 AND type = $3
      RETURNING *`,
    [sha256(String(body.token)), MAX_VERIFY_ATTEMPTS, 'password_reset'],
  );
  const v = rows[0];
  ensure(v, '00055');
  const ok = crypto.timingSafeEqual(Buffer.from(sha256(String(body.code).trim())), Buffer.from(v.code_hash));
  ensure(ok, '00054', { attemptsLeft: MAX_VERIFY_ATTEMPTS - v.attempt_count });
  return withTx(async (db) => {
    const verified = await db.query(
      'UPDATE email_verifications SET verified_at = now() WHERE id = $1 AND verified_at IS NULL AND used_at IS NULL RETURNING id',
      [v.id],
    );
    ensure(verified.rowCount, '00055');
    return result('00058', { message: 'Mã xác minh hợp lệ. Vui lòng đặt lại mật khẩu.' });
  });
}

/** POST user/reset-password/ - Đặt lại mật khẩu khi quên (dùng confirmToken từ gửi mã OTP). */
export async function resetPassword(body = {}) {
  const { email, token, newPassword } = body;
  ensure(isPresent(email) && isPresent(token) && isPresent(newPassword), '00580');
  ensure(isEmail(email), '00581');
  ensure(validPassword(newPassword), '00027');

  const { rows } = await query('SELECT * FROM users WHERE lower(email) = $1', [normEmail(email)]);
  const user = rows[0];
  ensure(user, '00036');

  // Kiểm tra token xác minh còn hiệu lực, đã xác minh và chưa dùng
  const { rows: vRows } = await query(
    `SELECT * FROM email_verifications
     WHERE user_id = $1 AND token_hash = $2 AND type = 'password_reset'
       AND verified_at IS NOT NULL AND used_at IS NULL AND expires_at > now()
     ORDER BY id DESC LIMIT 1
     FOR UPDATE`,
    [user.id, sha256(String(token))],
  );
  const v = vRows[0];
  ensure(v, '00585');

  // Cập nhật mật khẩu mới và đánh dấu token đã dùng
  const passwordHash = await bcrypt.hash(newPassword, 10);
  await withTx(async (db) => {
    await db.query('UPDATE users SET password_hash = $1 WHERE id = $2', [passwordHash, user.id]);
    await db.query('UPDATE email_verifications SET used_at = now() WHERE id = $1 AND used_at IS NULL', [v.id]);
    await audit(db, { userId: user.id }, 'user.reset_password', 'user', user.id);
  });

  return result('00076');
}

/** POST user/login/ */
export async function login(body = {}) {
  const { username, password, deviceId } = body;
  ensure(isPresent(username) && isPresent(password), '00005');
  ensure(validPassword(password), '00027');
  const { rows } = await query('SELECT * FROM users WHERE lower(username) = $1', [username.trim().toLowerCase()]);
  const user = rows[0];
  ensure(user, '00036');
  ensure(await bcrypt.compare(password, user.password_hash), '00045');
  ensure(user.is_active, '00043');
  ensure(user.email_verified_at, '00044', { email: user.email });

  const tokens = await withTx(async (db) => {
    if (isPresent(deviceId)) await db.query('UPDATE users SET device_id = $2 WHERE id = $1', [user.id, String(deviceId)]);
    const t = await createSession(db, user);
    await audit(db, { userId: user.id }, 'user.login', 'user', user.id);
    return t;
  });
  return result('00047', { user: toUserDto(user), ...tokens });
}

/** POST user/refresh-token/ - Xoay vòng refresh token. */
export async function refreshToken(body = {}) {
  ensure(isPresent(body.refreshToken), '00059');
  const hash = sha256(String(body.refreshToken));
  const { rows } = await query(
    `SELECT s.*, u.is_active, u.system_role FROM auth_sessions s JOIN users u ON u.id = s.user_id
      WHERE s.refresh_token_hash = $1`,
    [hash],
  );
  const s = rows[0];
  ensure(s, '00011');
  if (s.revoked_at) {
    // Refresh token đã dùng/thu hồi bị gửi lại => nghi bị lộ, thu hồi toàn bộ phiên của người dùng
    await revokeAllSessions(null, s.user_id);
    throw new AppError('00011');
  }
  ensure(new Date(s.expires_at) > new Date(), '00011');
  ensure(s.is_active, '00043');
  return withTx(async (db) => {
    const revoked = await db.query(
      'UPDATE auth_sessions SET revoked_at = now() WHERE id = $1 AND revoked_at IS NULL RETURNING id',
      [s.id],
    );
    ensure(revoked.rowCount, '00011');
    const tokens = await createSession(db, { id: s.user_id, system_role: s.system_role });
    return result('00065', tokens);
  });
}

/** POST user/logout/ - Thu hồi phiên theo refreshToken (và/hoặc Bearer token hiện tại). */
export async function logout(body = {}, authorization = '') {
  if (isPresent(body.refreshToken)) {
    await query('UPDATE auth_sessions SET revoked_at = now() WHERE refresh_token_hash = $1 AND revoked_at IS NULL', [
      sha256(String(body.refreshToken)),
    ]);
  }
  const [scheme, token] = String(authorization).split(' ');
  if (scheme === 'Bearer' && token) {
    try {
      const p = jwt.verify(token, env.jwtAccessSecret, { algorithms: ['HS256'], ignoreExpiration: true });
      if (p.sid) await query('UPDATE auth_sessions SET revoked_at = now() WHERE id = $1 AND revoked_at IS NULL', [p.sid]);
    } catch {
      /* token sai: bỏ qua, đăng xuất vẫn thành công phía client */
    }
  }
  return result('00050');
}

/** Tạo tài khoản quản trị hệ thống từ biến môi trường nếu chưa có. */
export async function ensureAdminAccount() {
  if (!env.adminEmail || !env.adminPassword) return;
  const { rows } = await query('SELECT id FROM users WHERE lower(email) = $1', [normEmail(env.adminEmail)]);
  if (rows[0]) return;
  const hash = await bcrypt.hash(env.adminPassword, 10);
  await query(
    `INSERT INTO users (email, password_hash, name, username, system_role, email_verified_at)
     VALUES ($1, $2, $3, 'admin', 'admin', now()) ON CONFLICT DO NOTHING`,
    [normEmail(env.adminEmail), hash, (cleanString(env.adminName, { min: 4, max: 29 }) ?? 'Quản trị viên')],
  );
  console.log(`[seed] đã tạo tài khoản quản trị ${env.adminEmail}`);
}
