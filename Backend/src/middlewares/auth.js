import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { AppError } from '../common/errors.js';
import { loadContext } from '../common/permissions.js';
import { query } from '../db/pool.js';

/**
 * Xác thực Bearer token (access JWT). Gắn req.ctx gồm danh tính + nhóm + vai trò.
 * - Thiếu token          -> 00006
 * - Token hết hạn        -> 00011
 * - Token sai / phiên đã thu hồi -> 00012
 */
export async function requireAuth(req, _res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) throw new AppError('00006');

  let payload;
  try {
    payload = jwt.verify(token, env.jwtAccessSecret, { algorithms: ['HS256'] });
  } catch (err) {
    throw new AppError(err.name === 'TokenExpiredError' ? '00011' : '00012');
  }

  const userId = Number(payload.sub);
  if (!Number.isInteger(userId) || userId <= 0) throw new AppError('00012');

  // Phiên bị thu hồi (đăng xuất, đổi mật khẩu, bị khóa) thì access token cũng mất hiệu lực
  if (payload.sid) {
    const { rows } = await query('SELECT revoked_at, expires_at FROM auth_sessions WHERE id = $1 AND user_id = $2', [
      payload.sid,
      userId,
    ]);
    const s = rows[0];
    if (!s || s.revoked_at || new Date(s.expires_at) < new Date()) throw new AppError('00012');
  }

  const ctx = await loadContext(userId, { sessionId: payload.sid ?? null });
  if (!ctx) throw new AppError('00012');
  if (!ctx.isActive) throw new AppError('00043');
  req.ctx = ctx;
  next();
}

/** Chỉ quản trị viên hệ thống (users.system_role = admin). */
export function requireSystemAdmin(req, _res, next) {
  if (req.ctx?.systemRole !== 'admin') throw new AppError('00017');
  next();
}
