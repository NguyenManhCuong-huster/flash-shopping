import { query } from '../../db/pool.js';
import { result } from '../../common/errors.js';
import { ensure, maybeJson, pageMeta, parsePage, toId } from '../../common/validate.js';

const toDto = (n) => ({
  id: n.id,
  type: n.type,
  title: n.title,
  body: n.body,
  data: n.data,
  read: !!n.read_at,
  pushStatus: n.push_status,
  createdAt: n.created_at,
});

/** GET notification/?unreadOnly=true&page&limit - Hộp thư thông báo của chính người dùng. */
export async function listNotifications(ctx, q = {}) {
  const p = parsePage(q, { defaultLimit: 30 });
  const unreadOnly = q.unreadOnly === 'true';
  const w = `user_id = $1 ${unreadOnly ? 'AND read_at IS NULL' : ''}`;
  const total = (await query(`SELECT count(*)::int AS n FROM notifications WHERE ${w}`, [ctx.userId])).rows[0].n;
  const unread = (await query('SELECT count(*)::int AS n FROM notifications WHERE user_id = $1 AND read_at IS NULL', [ctx.userId]))
    .rows[0].n;
  const { rows } = await query(
    `SELECT * FROM notifications WHERE ${w} ORDER BY created_at DESC, id DESC LIMIT ${p.limit} OFFSET ${p.offset}`,
    [ctx.userId],
  );
  return result('00550', { notifications: rows.map(toDto), unreadCount: unread, ...pageMeta(p, total) });
}

/** PUT notification/read/ {ids: [..]} hoặc {all: true} */
export async function markRead(ctx, body = {}) {
  if (body.all === true || body.all === 'true') {
    await query('UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL', [ctx.userId]);
    return result('00551');
  }
  const ids = maybeJson(body.ids);
  ensure(Array.isArray(ids) && ids.length > 0 && ids.length <= 200, '00022');
  const parsed = ids.map(toId);
  ensure(parsed.every(Boolean), '00023');
  await query('UPDATE notifications SET read_at = COALESCE(read_at, now()) WHERE user_id = $1 AND id = ANY($2::bigint[])', [
    ctx.userId,
    parsed,
  ]);
  return result('00551');
}
