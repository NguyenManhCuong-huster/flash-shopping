import { query } from '../../db/pool.js';
import { addDays, localDate } from '../../common/time.js';
import * as Meal from '../meal/meal.service.js';

const SUGGESTION_HOURS = [7, 17];

const localHour = (tz) =>
  Number(new Intl.DateTimeFormat('en-US', { timeZone: tz, hour: '2-digit', hourCycle: 'h23' }).format(new Date()));

const ddmm = (d) => d.split('-').reverse().slice(0, 2).join('/');

async function insertSuggestion(groupId, type, dedupeKey, title, payload, expiresAt) {
  const r = await query(
    `INSERT INTO ai_suggestions (group_id, type, dedupe_key, title, payload, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (group_id, type, dedupe_key) DO NOTHING`,
    [groupId, type, dedupeKey.slice(0, 200), title.slice(0, 200), JSON.stringify(payload), expiresAt],
  );
  return r.rowCount;
}

/**
 * Suggestion Worker (Bảng 35): chạy lúc 07:00 và 17:00 theo múi giờ của trưởng nhóm.
 * dedupe_key + UNIQUE(group_id, type, dedupe_key) đảm bảo không gợi ý lặp.
 */
export async function generateSuggestions({ groupId = null, force = false } = {}) {
  const { rows: groups } = await query(
    `SELECT gm.group_id, u.timezone FROM group_members gm JOIN users u ON u.id = gm.user_id
      WHERE gm.role = 'admin' AND ($1::bigint IS NULL OR gm.group_id = $1)`,
    [groupId],
  );
  let created = 0;
  for (const g of groups) {
    if (!force && !SUGGESTION_HOURS.includes(localHour(g.timezone))) continue;
    const today = localDate(new Date(), g.timezone);
    const tomorrow = addDays(today, 1);

    // 1) expiring_food: hạn dùng trong 48 giờ tới -> lên bữa tối với thực phẩm đó
    const { rows: expiring } = await query(
      `SELECT fi.id, fi.use_within, f.name FROM fridge_items fi JOIN foods f ON f.id = fi.food_id
        WHERE fi.group_id = $1 AND fi.use_within BETWEEN now() AND now() + interval '48 hours'`,
      [g.group_id],
    );
    for (const it of expiring) {
      created += await insertSuggestion(
        g.group_id, 'expiring_food', `${it.id}:${new Date(it.use_within).toISOString()}`,
        `${it.name} sắp hết hạn - lên bữa tối nay với ${it.name}?`,
        { foodName: it.name, useWithin: it.use_within, actions: [{ tool: 'create_meal_plan', arguments: { foodName: it.name, timestamp: today, name: 'tối' } }] },
        it.use_within,
      );
    }

    // 2) shopping_from_plan: bữa ngày mai thiếu nguyên liệu -> tạo danh sách + thêm nhiệm vụ
    const sysCtx = { groupId: g.group_id, groupRole: 'admin', timezone: g.timezone };
    const check = await Meal.checkIngredients(sysCtx, { date: tomorrow });
    const missing = check.data.missing;
    if (missing.length) {
      created += await insertSuggestion(
        g.group_id, 'shopping_from_plan', tomorrow,
        `Bữa ăn ngày ${ddmm(tomorrow)} còn thiếu ${missing.length} nguyên liệu - tạo danh sách đi chợ?`,
        {
          date: tomorrow,
          actions: [
            { tool: 'create_shopping_list', arguments: { name: `Đi chợ cho ngày ${ddmm(tomorrow)}`, date: today } },
            {
              tool: 'add_shopping_tasks',
              arguments: { listId: '$ref:0.listId', tasks: missing.slice(0, 30).map((m) => ({ foodName: m.food.name, quantity: m.missingQuantity })) },
            },
          ],
        },
        new Date(Date.now() + 36 * 3600_000),
      );
    }

    // 3) low_stock: thực phẩm hay dùng trong 14 ngày qua nhưng tủ lạnh đã hết
    const { rows: low } = await query(
      `SELECT f.id, f.name FROM meal_plans mp JOIN foods f ON f.id = mp.food_id
        WHERE mp.group_id = $1 AND mp.planned_at >= now() - interval '14 days' AND mp.planned_at < now()
          AND NOT EXISTS (SELECT 1 FROM fridge_items fi WHERE fi.group_id = mp.group_id AND fi.food_id = f.id)
        GROUP BY f.id, f.name HAVING count(*) >= 2 ORDER BY count(*) DESC LIMIT 10`,
      [g.group_id],
    );
    if (low.length) {
      const tasks = low.map((f) => ({ foodName: f.name, quantity: 1 }));
      const next = (
        await query(
          `SELECT id FROM shopping_lists WHERE group_id = $1 AND shopping_date >= $2::date ORDER BY shopping_date, id LIMIT 1`,
          [g.group_id, today],
        )
      ).rows[0];
      const actions = next
        ? [{ tool: 'add_shopping_tasks', arguments: { listId: next.id, tasks } }]
        : [
          { tool: 'create_shopping_list', arguments: { name: 'Bổ sung đồ hay dùng', date: today } },
          { tool: 'add_shopping_tasks', arguments: { listId: '$ref:0.listId', tasks } },
        ];
      created += await insertSuggestion(
        g.group_id, 'low_stock', `${today}:${low.map((f) => f.id).sort((a, b) => a - b).join(',')}`,
        `Đã hết ${low.map((f) => f.name).slice(0, 3).join(', ')}${low.length > 3 ? '...' : ''} - thêm vào danh sách mua?`,
        { foods: low.map((f) => f.name), actions },
        new Date(Date.now() + 24 * 3600_000),
      );
    }
  }
  if (created) console.log(`[ai] tạo ${created} gợi ý chủ động`);
  return created;
}
