import bcrypt from 'bcryptjs';
import { query, withTx } from '../../db/pool.js';
import { AppError, result } from '../../common/errors.js';
import { cleanString, ensure, isPresent, USERNAME_RE } from '../../common/validate.js';
import { isValidTimeZone } from '../../common/time.js';
import { audit } from '../../common/audit.js';
import { removeByUrl } from '../../middlewares/upload.js';
import { revokeAllSessions } from '../auth/token.service.js';
import { LANGUAGES } from '../auth/auth.service.js';
import { toUserDto } from './user.mapper.js';

async function profile(userId) {
  const { rows } = await query(
    `SELECT u.*, gm.group_id, gm.role AS group_role, g.name AS group_name
       FROM users u
       LEFT JOIN group_members gm ON gm.user_id = u.id
       LEFT JOIN groups g ON g.id = gm.group_id
      WHERE u.id = $1`,
    [userId],
  );
  const u = rows[0];
  if (!u) throw new AppError('00052');
  return {
    ...toUserDto(u),
    group: u.group_id ? { id: u.group_id, name: u.group_name, role: u.group_role } : null,
  };
}

/** GET user/ */
export async function getMe(ctx) {
  return result('00089', { user: await profile(ctx.userId) });
}

/** PUT user/ (multipart: username, name, language, timezone, image) */
export async function updateMe(ctx, body = {}, file = null, imageUrl = null) {
  const sets = [];
  const params = [ctx.userId];
  const push = (col, val) => {
    params.push(val);
    sets.push(`${col} = $${params.length}`);
  };

  if (isPresent(body.username)) {
    const username = String(body.username).trim();
    ensure(USERNAME_RE.test(username), '00081');
    push('username', username);
  }
  if (isPresent(body.name)) {
    const name = cleanString(body.name, { min: 4, max: 29 });
    ensure(name, '00077');
    push('name', name);
  }
  if (isPresent(body.language)) {
    ensure(LANGUAGES.includes(String(body.language).trim()), '00079');
    push('language', String(body.language).trim());
  }
  if (isPresent(body.timezone)) {
    ensure(isValidTimeZone(String(body.timezone).trim()), '00505');
    push('timezone', String(body.timezone).trim());
  }
  if (file) push('image_url', imageUrl);
  ensure(sets.length > 0, '00025');

  let old;
  try {
    old = await withTx(async (db) => {
      const prev = await db.query('SELECT image_url FROM users WHERE id = $1 FOR UPDATE', [ctx.userId]);
      await db.query(`UPDATE users SET ${sets.join(', ')} WHERE id = $1`, params);
      await audit(db, ctx, 'user.update_profile', 'user', ctx.userId, { fields: Object.keys(body), image: !!file });
      return prev.rows[0];
    });
  } catch (err) {
    if (err.code === '23505') throw new AppError('00084');
    throw err;
  }
  if (file && old?.image_url) removeByUrl(old.image_url);
  return result('00086', { user: await profile(ctx.userId) });
}

/** POST user/change-password/ */
export async function changePassword(ctx, body = {}) {
  const { oldPassword, newPassword } = body;
  const valid = (p) => typeof p === 'string' && p.length >= 6 && p.length <= 20;
  ensure(valid(oldPassword) && valid(newPassword), '00069');
  const { rows } = await query('SELECT password_hash FROM users WHERE id = $1', [ctx.userId]);
  ensure(rows[0], '00052');
  ensure(await bcrypt.compare(oldPassword, rows[0].password_hash), '00072');
  ensure(oldPassword !== newPassword, '00073');
  const hash = await bcrypt.hash(newPassword, 10);
  await withTx(async (db) => {
    await db.query('UPDATE users SET password_hash = $2 WHERE id = $1', [ctx.userId, hash]);
    // Đăng xuất mọi thiết bị khác, giữ phiên hiện tại
    await revokeAllSessions(db, ctx.userId, ctx.sessionId);
    await audit(db, ctx, 'user.change_password', 'user', ctx.userId);
  });
  return result('00076');
}

/**
 * DELETE user/ - Xóa tài khoản. Nếu là trưởng nhóm: chuyển quyền cho thành viên vào nhóm sớm nhất,
 * hoặc giải tán nhóm khi không còn ai (nhóm luôn có đúng một trưởng nhóm).
 */
export async function deleteMe(ctx) {
  const imageUrl = await withTx(async (db) => {
    const me = await db.query('SELECT image_url FROM users WHERE id = $1 FOR UPDATE', [ctx.userId]);
    ensure(me.rows[0], '00052');
    const m = await db.query('SELECT group_id, role FROM group_members WHERE user_id = $1 FOR UPDATE', [ctx.userId]);
    const membership = m.rows[0];
    if (membership?.role === 'admin') {
      const next = await db.query(
        `SELECT user_id FROM group_members WHERE group_id = $1 AND user_id <> $2 ORDER BY joined_at LIMIT 1`,
        [membership.group_id, ctx.userId],
      );
      if (next.rows[0]) {
        await db.query(`UPDATE group_members SET role = 'member' WHERE user_id = $1`, [ctx.userId]);
        await db.query(`UPDATE group_members SET role = 'admin' WHERE user_id = $1`, [next.rows[0].user_id]);
      } else {
        await db.query('DELETE FROM groups WHERE id = $1', [membership.group_id]);
      }
    }
    await audit(db, ctx, 'user.delete', 'user', ctx.userId);
    await db.query('DELETE FROM users WHERE id = $1', [ctx.userId]);
    return me.rows[0].image_url;
  });
  removeByUrl(imageUrl);
  return result('00092');
}

/** POST user/device/ - Đăng ký token thiết bị nhận push (FCM). */
export async function registerDevice(ctx, body = {}) {
  const token = cleanString(body.token, { min: 10, max: 4096 });
  ensure(token, '00553');
  const platform = ['android', 'ios', 'web'].includes(body.platform) ? body.platform : 'android';
  await withTx(async (db) => {
    await db.query(
      `INSERT INTO device_tokens (user_id, token, platform) VALUES ($1, $2, $3)
       ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform,
                                         is_active = TRUE, updated_at = now()`,
      [ctx.userId, token, platform],
    );
    await db.query('UPDATE users SET device_id = $2 WHERE id = $1', [ctx.userId, token]);
  });
  return result('00552');
}

/** DELETE user/device/ */
export async function unregisterDevice(ctx, body = {}) {
  const token = cleanString(body.token, { min: 10, max: 4096 });
  ensure(token, '00553');
  await query('UPDATE device_tokens SET is_active = FALSE, updated_at = now() WHERE user_id = $1 AND token = $2', [
    ctx.userId,
    token,
  ]);
  return result('00554');
}
