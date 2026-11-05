import { query, withTx } from '../../db/pool.js';
import { result } from '../../common/errors.js';
import { ensure, isoDate, isPresent, pageMeta, parsePage, toId } from '../../common/validate.js';
import { audit } from '../../common/audit.js';
import { revokeAllSessions } from '../auth/token.service.js';
import { toUserDto } from '../user/user.mapper.js';

/** GET admin/logs/?page&limit&action&userId&source&from&to */
export async function getLogs(ctx, q = {}) {
  const p = parsePage(q, { defaultLimit: 50 });
  const where = [];
  const params = [];
  const add = (sql, v) => {
    params.push(v);
    where.push(sql.replace('?', `$${params.length}`));
  };
  if (isPresent(q.action)) add('l.action ILIKE ?', `%${q.action}%`);
  if (toId(q.userId)) add('l.actor_user_id = ?', toId(q.userId));
  if (['app', 'ai', 'system'].includes(q.source)) add('l.source = ?', q.source);
  if (isoDate(q.from)) add('l.occurred_at >= ?::date', q.from);
  if (isoDate(q.to)) add(`l.occurred_at < (?::date + 1)`, q.to);
  const w = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const total = (await query(`SELECT count(*)::int AS n FROM audit_logs l ${w}`, params)).rows[0].n;
  const { rows } = await query(
    `SELECT l.id, l.action, l.entity_type, l.entity_id, l.occurred_at, l.metadata, l.source, l.ai_action_id,
            l.actor_user_id, u.email AS actor_email, u.name AS actor_name
       FROM audit_logs l LEFT JOIN users u ON u.id = l.actor_user_id
       ${w} ORDER BY l.occurred_at DESC, l.id DESC LIMIT ${p.limit} OFFSET ${p.offset}`,
    params,
  );
  const logs = rows.map((r) => ({
    id: r.id,
    action: r.action,
    entityType: r.entity_type,
    entityId: r.entity_id,
    occurredAt: r.occurred_at,
    metadata: r.metadata,
    source: r.source,
    aiActionId: r.ai_action_id,
    actor: r.actor_user_id ? { id: r.actor_user_id, email: r.actor_email, name: r.actor_name } : null,
  }));
  return result('00109', { logs, ...pageMeta(p, total) });
}

/** GET admin/users/?q&page&limit */
export async function listUsers(ctx, q = {}) {
  const p = parsePage(q, { defaultLimit: 50 });
  const params = [];
  let w = '';
  if (isPresent(q.q)) {
    params.push(`%${String(q.q).trim()}%`);
    w = 'WHERE u.email ILIKE $1 OR u.name ILIKE $1 OR u.username ILIKE $1';
  }
  const total = (await query(`SELECT count(*)::int AS n FROM users u ${w}`, params)).rows[0].n;
  const { rows } = await query(
    `SELECT u.*, gm.group_id, gm.role AS group_role FROM users u
       LEFT JOIN group_members gm ON gm.user_id = u.id
       ${w} ORDER BY u.id DESC LIMIT ${p.limit} OFFSET ${p.offset}`,
    params,
  );
  const users = rows.map((u) => ({ ...toUserDto(u), groupId: u.group_id, groupRole: u.group_role }));
  return result('00560', { users, ...pageMeta(p, total) });
}

/** PUT admin/users/ {userId, isActive?, systemRole?} - Khóa/mở khóa, cấp/thu quyền quản trị. */
export async function updateUser(ctx, body = {}) {
  const userId = toId(body.userId);
  ensure(userId, '00007');
  const sets = [];
  const params = [userId];
  let deactivate = false;
  if (body.isActive !== undefined) {
    const v = body.isActive === true || body.isActive === 'true' ? true : body.isActive === false || body.isActive === 'false' ? false : null;
    ensure(v !== null, '00563');
    ensure(!(userId === ctx.userId && v === false), '00562');
    params.push(v);
    sets.push(`is_active = $${params.length}`);
    deactivate = v === false;
  }
  if (body.systemRole !== undefined) {
    ensure(['user', 'admin'].includes(body.systemRole), '00563');
    ensure(!(userId === ctx.userId && body.systemRole !== 'admin'), '00562');
    params.push(body.systemRole);
    sets.push(`system_role = $${params.length}`);
  }
  ensure(sets.length, '00025');
  const user = await withTx(async (db) => {
    const { rows } = await db.query(`UPDATE users SET ${sets.join(', ')} WHERE id = $1 RETURNING *`, params);
    ensure(rows[0], '00052');
    if (deactivate) await revokeAllSessions(db, userId);
    await audit(db, ctx, 'admin.update_user', 'user', userId, { isActive: body.isActive, systemRole: body.systemRole });
    return rows[0];
  });
  return result('00561', { user: toUserDto(user) });
}
