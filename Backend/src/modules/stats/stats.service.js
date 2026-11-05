import { query } from '../../db/pool.js';
import { result } from '../../common/errors.js';
import { ensure, isoDate, isPresent, pageMeta, parsePage } from '../../common/validate.js';
import { addDays, daysBetween, localDate, zonedDateTimeToUtc } from '../../common/time.js';
import { requireMember } from '../../common/permissions.js';

const EVENT_TYPES = ['purchase', 'add', 'consume', 'discard', 'adjust', 'remove'];

/** from/to dạng YYYY-MM-DD theo múi giờ người dùng, mặc định 30 ngày gần nhất, tối đa 366 ngày. */
function resolvePeriod(q, tz) {
  const today = localDate(new Date(), tz);
  const to = isPresent(q.to) ? isoDate(q.to) : today;
  const from = isPresent(q.from) ? isoDate(q.from) : to && addDays(to, -29);
  ensure(from && to, '00541');
  const span = daysBetween(from, to);
  ensure(span >= 0 && span <= 366, '00541');
  return { from, to, start: zonedDateTimeToUtc(from, 0, 0, 0, tz), end: zonedDateTimeToUtc(addDays(to, 1), 0, 0, 0, tz) };
}

/** GET stats/?from&to - Báo cáo mua sắm và tiêu thụ/hủy bỏ của nhóm. */
export async function summary(ctx, q = {}) {
  const groupId = requireMember(ctx, '00185');
  const { from, to, start, end } = resolvePeriod(q, ctx.timezone);
  const params = [groupId, start, end];
  const range = 'group_id = $1 AND occurred_at >= $2 AND occurred_at < $3';

  const totals = (
    await query(`SELECT type, count(*)::int AS events FROM stock_events WHERE ${range} GROUP BY type`, params)
  ).rows.reduce((acc, r) => ({ ...acc, [r.type]: r.events }), Object.fromEntries(EVENT_TYPES.map((t) => [t, 0])));

  const byFood = (
    await query(
      `SELECT food_name, unit_name, category_name,
              COALESCE(sum(quantity) FILTER (WHERE type = 'purchase'), 0) AS purchased,
              COALESCE(sum(quantity) FILTER (WHERE type = 'add'), 0)      AS added,
              COALESCE(sum(quantity) FILTER (WHERE type = 'consume'), 0)  AS consumed,
              COALESCE(sum(quantity) FILTER (WHERE type = 'discard'), 0)  AS discarded
         FROM stock_events WHERE ${range}
        GROUP BY food_name, unit_name, category_name
        ORDER BY count(*) DESC, food_name
        LIMIT 100`,
      params,
    )
  ).rows.map((r) => ({
    foodName: r.food_name,
    unit: r.unit_name,
    category: r.category_name,
    purchased: r.purchased,
    added: r.added,
    consumed: r.consumed,
    discarded: r.discarded,
  }));

  const byCategory = (
    await query(
      `SELECT category_name,
              count(*) FILTER (WHERE type IN ('purchase', 'add'))::int AS in_events,
              count(*) FILTER (WHERE type = 'consume')::int AS consume_events,
              count(*) FILTER (WHERE type = 'discard')::int AS discard_events
         FROM stock_events WHERE ${range}
        GROUP BY category_name ORDER BY count(*) DESC`,
      params,
    )
  ).rows.map((r) => ({
    category: r.category_name,
    inEvents: r.in_events,
    consumeEvents: r.consume_events,
    discardEvents: r.discard_events,
  }));

  const daily = (
    await query(
      `SELECT to_char((occurred_at AT TIME ZONE $4)::date, 'YYYY-MM-DD') AS day,
              count(*) FILTER (WHERE type IN ('purchase', 'add'))::int AS in_events,
              count(*) FILTER (WHERE type = 'consume')::int AS consume_events,
              count(*) FILTER (WHERE type = 'discard')::int AS discard_events
         FROM stock_events WHERE ${range}
        GROUP BY 1 ORDER BY 1`,
      [...params, ctx.timezone],
    )
  ).rows.map((r) => ({ date: r.day, inEvents: r.in_events, consumeEvents: r.consume_events, discardEvents: r.discard_events }));

  const shopping = (
    await query(
      `SELECT count(DISTINCT sl.id)::int AS lists,
              count(t.id)::int AS tasks,
              count(t.id) FILTER (WHERE t.status = 'bought')::int AS bought_tasks
         FROM shopping_lists sl LEFT JOIN shopping_tasks t ON t.list_id = sl.id
        WHERE sl.group_id = $1 AND sl.shopping_date BETWEEN $2::date AND $3::date`,
      [groupId, from, to],
    )
  ).rows[0];

  const usedEvents = totals.consume + totals.discard;
  return result('00540', {
    from,
    to,
    totals,
    wasteRate: usedEvents ? Math.round((totals.discard / usedEvents) * 1000) / 1000 : 0,
    shopping: { lists: shopping.lists, tasks: shopping.tasks, boughtTasks: shopping.bought_tasks },
    byFood,
    byCategory,
    daily,
  });
}

/** GET stats/events/?from&to&type&page&limit - Lịch sử biến động kho (phân trang <= 50). */
export async function events(ctx, q = {}) {
  const groupId = requireMember(ctx, '00185');
  const { from, to, start, end } = resolvePeriod(q, ctx.timezone);
  const p = parsePage(q, { defaultLimit: 50 });
  const params = [groupId, start, end];
  let w = 'e.group_id = $1 AND e.occurred_at >= $2 AND e.occurred_at < $3';
  if (EVENT_TYPES.includes(q.type)) {
    params.push(q.type);
    w += ` AND e.type = $${params.length}`;
  }
  const total = (await query(`SELECT count(*)::int AS n FROM stock_events e WHERE ${w}`, params)).rows[0].n;
  const { rows } = await query(
    `SELECT e.*, u.name AS actor_name FROM stock_events e LEFT JOIN users u ON u.id = e.actor_user_id
      WHERE ${w} ORDER BY e.occurred_at DESC, e.id DESC LIMIT ${p.limit} OFFSET ${p.offset}`,
    params,
  );
  const list = rows.map((e) => ({
    id: e.id,
    type: e.type,
    foodId: e.food_id,
    foodName: e.food_name,
    unit: e.unit_name,
    category: e.category_name,
    quantity: e.quantity,
    note: e.note,
    shoppingTaskId: e.shopping_task_id,
    actor: e.actor_user_id ? { id: e.actor_user_id, name: e.actor_name } : null,
    occurredAt: e.occurred_at,
  }));
  return result('00525', { from, to, events: list, ...pageMeta(p, total) });
}
