import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env.js';
import { query } from '../../db/pool.js';

export const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');

/** Tạo phiên mới: access JWT ngắn hạn + refresh token ngẫu nhiên (chỉ lưu hash). */
export async function createSession(db, user) {
  const refreshToken = crypto.randomBytes(48).toString('base64url');
  const expiresAt = new Date(Date.now() + env.refreshTokenTtlDays * 86400_000);
  const { rows } = await (db ?? { query }).query(
    `INSERT INTO auth_sessions (user_id, refresh_token_hash, expires_at) VALUES ($1, $2, $3) RETURNING id`,
    [user.id, sha256(refreshToken), expiresAt],
  );
  const sessionId = rows[0].id;
  const accessToken = jwt.sign({ sub: String(user.id), role: user.system_role, sid: sessionId }, env.jwtAccessSecret, {
    algorithm: 'HS256',
    expiresIn: env.jwtAccessTtl,
  });
  const { exp } = jwt.decode(accessToken);
  return { accessToken, refreshToken, accessTokenExpiresAt: new Date(exp * 1000), refreshTokenExpiresAt: expiresAt };
}

export async function revokeAllSessions(db, userId, exceptSessionId = null) {
  await (db ?? { query }).query(
    `UPDATE auth_sessions SET revoked_at = now()
      WHERE user_id = $1 AND revoked_at IS NULL AND ($2::bigint IS NULL OR id <> $2)`,
    [userId, exceptSessionId],
  );
}
