import { AppError } from './errors.js';
import { query } from '../db/pool.js';

/**
 * Ngữ cảnh thực thi: danh tính và phạm vi nhóm luôn lấy từ token + group_members,
 * không bao giờ lấy từ tham số do client/AI gửi lên (NFR13).
 *
 * ctx = { userId, systemRole, name, username, timezone, language,
 *         groupId, groupRole, source: 'app'|'ai'|'system', aiActionId }
 */
export async function loadContext(userId, extra = {}) {
  const { rows } = await query(
    `SELECT u.id, u.name, u.username, u.email, u.system_role, u.timezone, u.language, u.is_active,
            gm.group_id, gm.role AS group_role
       FROM users u
       LEFT JOIN group_members gm ON gm.user_id = u.id
      WHERE u.id = $1`,
    [userId],
  );
  const u = rows[0];
  if (!u) return null;
  return {
    userId: u.id,
    name: u.name,
    username: u.username,
    email: u.email,
    systemRole: u.system_role,
    timezone: u.timezone,
    language: u.language,
    isActive: u.is_active,
    groupId: u.group_id ?? null,
    groupRole: u.group_role ?? null,
    source: 'app',
    aiActionId: null,
    ...extra,
  };
}

/** Bắt buộc thuộc một nhóm; trả về groupId. */
export function requireMember(ctx, code) {
  if (!ctx.groupId) throw new AppError(code);
  return ctx.groupId;
}

/** Bắt buộc là trưởng nhóm (group_members.role = admin). */
export function requireLeader(ctx, notMemberCode, notLeaderCode) {
  requireMember(ctx, notMemberCode);
  if (ctx.groupRole !== 'admin') throw new AppError(notLeaderCode);
  return ctx.groupId;
}

export const isLeader = (ctx) => ctx.groupId != null && ctx.groupRole === 'admin';

/** Quyền quản trị hệ thống (users.system_role) - độc lập với quyền trưởng nhóm. */
export function requireSystemAdmin(ctx) {
  if (ctx.systemRole !== 'admin') throw new AppError('00017');
}
