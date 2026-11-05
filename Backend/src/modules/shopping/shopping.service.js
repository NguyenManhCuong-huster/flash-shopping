import crypto from 'node:crypto';
import { query, withTx } from '../../db/pool.js';
import { AppError, result } from '../../common/errors.js';
import { messageOf } from '../../common/codes.js';
import {
  cleanString, ensure, isoDate, isPresent, LOCATIONS, maybeJson, optionalNote, pageMeta, parsePage, positiveNumber, toId,
} from '../../common/validate.js';
import { requireLeader, requireMember } from '../../common/permissions.js';
import { audit } from '../../common/audit.js';
import { findFoodByName } from '../food/food.repo.js';
import { recordStockEvent } from '../stock/stock.repo.js';
import { parseUseWithin } from '../fridge/fridge.service.js';
import { triggerExpiryScan } from '../notification/expiry.job.js';

const LIST_SELECT = `
  SELECT sl.*, au.name AS assigned_name, au.username AS assigned_username, au.image_url AS assigned_image
    FROM shopping_lists sl
    LEFT JOIN users au ON au.id = sl.assigned_user_id`;

const TASK_SELECT = `
  SELECT t.id, t.list_id, t.quantity, t.status, t.bought_quantity, t.bought_at, t.bought_by,
         bu.name AS bought_by_name,
         f.id AS food_id, f.name AS food_name, f.image_url AS food_image_url,
         c.id AS category_id, c.name AS category_name, un.id AS unit_id, un.name AS unit_name
    FROM shopping_tasks t
    JOIN foods f ON f.id = t.food_id
    JOIN categories c ON c.id = f.category_id
    JOIN units un ON un.id = f.unit_id
    LEFT JOIN users bu ON bu.id = t.bought_by`;

const toTaskDto = (t) => ({
  id: t.id,
  listId: t.list_id,
  food: {
    id: t.food_id,
    name: t.food_name,
    imageUrl: t.food_image_url,
    category: { id: t.category_id, name: t.category_name },
    unit: { id: t.unit_id, name: t.unit_name },
  },
  quantity: t.quantity,
  status: t.status,
  boughtQuantity: t.bought_quantity,
  boughtAt: t.bought_at,
  boughtBy: t.bought_by ? { id: t.bought_by, name: t.bought_by_name } : null,
});

function toListDto(l, tasks = []) {
  const bought = tasks.filter((t) => t.status === 'bought').length;
  return {
    id: l.id,
    name: l.name,
    note: l.note,
    date: l.shopping_date,
    assignedTo: l.assigned_user_id
      ? { id: l.assigned_user_id, name: l.assigned_name, username: l.assigned_username, imageUrl: l.assigned_image }
      : null,
    createdBy: l.created_by,
    createdAt: l.created_at,
    updatedAt: l.updated_at,
    tasks: tasks.map(toTaskDto),
    progress: { total: tasks.length, bought, done: tasks.length > 0 && bought === tasks.length },
  };
}

async function withTasks(lists) {
  if (!lists.length) return [];
  const { rows } = await query(`${TASK_SELECT} WHERE t.list_id = ANY($1::bigint[]) ORDER BY t.status DESC, t.id`, [
    lists.map((l) => l.id),
  ]);
  const byList = new Map();
  for (const t of rows) {
    if (!byList.has(t.list_id)) byList.set(t.list_id, []);
    byList.get(t.list_id).push(t);
  }
  return lists.map((l) => toListDto(l, byList.get(l.id) ?? []));
}

export async function loadList(groupId, listId) {
  const { rows } = await query(`${LIST_SELECT} WHERE sl.id = $1 AND sl.group_id = $2`, [listId, groupId]);
  return rows[0] ? (await withTasks(rows))[0] : null;
}

/** Người được giao phải tồn tại và thuộc cùng nhóm (include bắt buộc của UC03). */
async function resolveAssignee(db, groupId, username, notFoundCode, otherGroupCode) {
  const u = (await db.query('SELECT id FROM users WHERE username = $1', [String(username).trim()])).rows[0];
  ensure(u, notFoundCode);
  const m = await db.query('SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2', [groupId, u.id]);
  ensure(m.rowCount, otherGroupCode);
  return u.id;
}

// ===================== Danh sách mua sắm =====================

/** POST shopping/ - Trưởng nhóm tạo danh sách, có thể giao cho thành viên. */
export async function createList(ctx, body = {}) {
  ensure(isPresent(body.name) || isPresent(body.date), '00238');
  const name = cleanString(body.name, { min: 1, max: 150 });
  ensure(name, '00239');
  const note = optionalNote(body.note);
  ensure(note.ok, '00241');
  const date = isoDate(body.date);
  ensure(date, '00242');
  const groupId = requireLeader(ctx, '00288', '00243');

  const id = await withTx(async (db) => {
    const assignee = isPresent(body.assignToUsername)
      ? await resolveAssignee(db, groupId, body.assignToUsername, '00245', '00246')
      : null;
    const { rows } = await db.query(
      `INSERT INTO shopping_lists (group_id, assigned_user_id, name, note, shopping_date, created_by)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
      [groupId, assignee, name, note.value, date, ctx.userId],
    );
    await audit(db, ctx, 'shopping.create_list', 'shopping_list', rows[0].id, { name, assignee, date });
    return rows[0].id;
  });
  return result('00249', { listId: id, list: await loadList(groupId, id) });
}

/** PUT shopping/ - Sửa tên/người được giao/ghi chú/ngày. newAssignToUsername = "" để bỏ giao. */
export async function updateList(ctx, body = {}) {
  const listId = toId(body.listId);
  ensure(listId, '00251');
  const keys = ['newName', 'newAssignToUsername', 'newNote', 'newDate'];
  ensure(keys.some((k) => body[k] !== undefined), '00252');
  let newName = null;
  if (body.newName !== undefined) {
    newName = cleanString(body.newName, { min: 1, max: 150 });
    ensure(newName, '00253');
  }
  if (body.newAssignToUsername !== undefined) ensure(typeof body.newAssignToUsername === 'string', '00254');
  const newNote = body.newNote !== undefined ? optionalNote(body.newNote) : null;
  if (newNote) ensure(newNote.ok, '00255');
  let newDate = null;
  if (body.newDate !== undefined) {
    newDate = isoDate(body.newDate);
    ensure(newDate, '00256');
  }
  const groupId = requireLeader(ctx, '00288', '00258');

  await withTx(async (db) => {
    const cur = (await db.query('SELECT id FROM shopping_lists WHERE id = $1 AND group_id = $2 FOR UPDATE', [listId, groupId]))
      .rows[0];
    ensure(cur, '00260');
    const sets = ['updated_at = now()'];
    const params = [listId];
    const push = (col, v) => {
      params.push(v);
      sets.push(`${col} = $${params.length}`);
    };
    if (newName) push('name', newName);
    if (newNote) push('note', newNote.value);
    if (newDate) push('shopping_date', newDate);
    if (body.newAssignToUsername !== undefined) {
      const assignee = body.newAssignToUsername.trim() === ''
        ? null
        : await resolveAssignee(db, groupId, body.newAssignToUsername, '00262', '00263');
      push('assigned_user_id', assignee);
    }
    await db.query(`UPDATE shopping_lists SET ${sets.join(', ')} WHERE id = $1`, params);
    await audit(db, ctx, 'shopping.update_list', 'shopping_list', listId, {
      newName, newDate, newAssignToUsername: body.newAssignToUsername,
    });
  });
  return result('00266', { list: await loadList(groupId, listId) });
}

/** DELETE shopping/ {listId} */
export async function deleteList(ctx, body = {}) {
  ensure(body && Object.keys(body).length, '00267');
  const listId = toId(body.listId);
  ensure(listId, '00268');
  const groupId = requireLeader(ctx, '00288', '00270');
  await withTx(async (db) => {
    const del = await db.query('DELETE FROM shopping_lists WHERE id = $1 AND group_id = $2 RETURNING name', [listId, groupId]);
    ensure(del.rowCount, '00272');
    await audit(db, ctx, 'shopping.delete_list', 'shopping_list', listId, { name: del.rows[0].name });
  });
  return result('00275');
}

/** GET shopping/task/?from&to&status=open|done&assignedToMe=true&page&limit - Danh sách kèm nhiệm vụ. */
export async function listLists(ctx, q = {}) {
  const groupId = requireMember(ctx, '00288');
  const p = parsePage(q, { defaultLimit: 20 });
  const params = [groupId];
  const where = ['sl.group_id = $1'];
  const add = (sql, v) => {
    params.push(v);
    where.push(sql.replaceAll('?', `$${params.length}`));
  };
  if (isoDate(q.from)) add('sl.shopping_date >= ?::date', q.from);
  if (isoDate(q.to)) add('sl.shopping_date <= ?::date', q.to);
  if (q.assignedToMe === 'true') add('sl.assigned_user_id = ?', ctx.userId);
  if (q.status === 'open') where.push(`(NOT EXISTS (SELECT 1 FROM shopping_tasks t WHERE t.list_id = sl.id)
                                       OR EXISTS (SELECT 1 FROM shopping_tasks t WHERE t.list_id = sl.id AND t.status = 'pending'))`);
  if (q.status === 'done') where.push(`EXISTS (SELECT 1 FROM shopping_tasks t WHERE t.list_id = sl.id)
                                       AND NOT EXISTS (SELECT 1 FROM shopping_tasks t WHERE t.list_id = sl.id AND t.status = 'pending')`);
  const w = where.join(' AND ');
  const total = (await query(`SELECT count(*)::int AS n FROM shopping_lists sl WHERE ${w}`, params)).rows[0].n;
  const { rows } = await query(
    `${LIST_SELECT} WHERE ${w} ORDER BY sl.shopping_date DESC, sl.id DESC LIMIT ${p.limit} OFFSET ${p.offset}`,
    params,
  );
  return result('00292', { lists: await withTasks(rows), ...pageMeta(p, total) });
}

/** GET shopping/:listId/ */
export async function getList(ctx, rawId) {
  const listId = toId(rawId);
  ensure(rawId !== undefined, '00022');
  ensure(listId, '00023');
  const groupId = requireMember(ctx, '00288');
  const list = await loadList(groupId, listId);
  ensure(list, '00260');
  return result('00570', { list });
}

// ===================== Nhiệm vụ mua (shopping_tasks) =====================

/**
 * POST shopping/task/ {listId, tasks:[{foodName, quantity}]}
 * Kiểm tra từng mục; lưu các mục hợp lệ, trả rõ mục lỗi (UC03 bước 5, 5a).
 */
export async function createTasks(ctx, body = {}) {
  ensure(body.listId !== undefined || body.tasks !== undefined, '00276');
  const listId = toId(body.listId);
  ensure(listId, '00277');
  const tasks = maybeJson(body.tasks);
  ensure(Array.isArray(tasks) && tasks.length > 0 && tasks.length <= 100, '00278');
  const groupId = requireLeader(ctx, '00288', '00281');

  const out = await withTx(async (db) => {
    const list = (await db.query('SELECT id FROM shopping_lists WHERE id = $1 AND group_id = $2 FOR UPDATE', [listId, groupId]))
      .rows[0];
    ensure(list, '00283');
    const created = [];
    const failed = [];
    for (const [index, t] of tasks.entries()) {
      const foodName = typeof t?.foodName === 'string' ? t.foodName.trim() : '';
      const quantity = positiveNumber(t?.quantity);
      if (!foodName || !quantity) {
        failed.push({ index, foodName: t?.foodName ?? null, code: '00279' });
        continue;
      }
      const food = await findFoodByName(db, groupId, foodName);
      if (!food) {
        failed.push({ index, foodName, code: '00285' });
        continue;
      }
      const ins = await db.query(
        `INSERT INTO shopping_tasks (list_id, group_id, food_id, quantity) VALUES ($1, $2, $3, $4)
         ON CONFLICT (list_id, food_id) DO NOTHING RETURNING id`,
        [listId, groupId, food.id, quantity],
      );
      if (!ins.rowCount) {
        failed.push({ index, foodName, code: '00285x' });
        continue;
      }
      created.push({ index, taskId: ins.rows[0].id, foodName: food.name, quantity });
    }
    if (created.length) {
      await db.query('UPDATE shopping_lists SET updated_at = now() WHERE id = $1', [listId]);
      await audit(db, ctx, 'shopping.create_tasks', 'shopping_list', listId, { count: created.length });
    }
    return { created, failed };
  });

  const failed = out.failed.map((f) => ({ ...f, message: messageOf(f.code) }));
  if (!out.created.length) throw new AppError(failed[0].code, { created: [], failed });
  return result(failed.length ? '00507' : '00287', {
    created: out.created,
    failed,
    list: await loadList(groupId, listId),
  });
}

/** PUT shopping/task/ {taskId, newFoodName?, newQuantity?} */
export async function updateTask(ctx, body = {}) {
  ensure(body && Object.keys(body).length, '00300');
  const taskId = toId(body.taskId);
  ensure(taskId, '00301');
  ensure(isPresent(body.newFoodName) || isPresent(body.newQuantity), '00302');
  if (body.newFoodName !== undefined && body.newFoodName !== '') ensure(cleanString(body.newFoodName, { max: 150 }), '00303');
  let newQuantity = null;
  if (isPresent(body.newQuantity)) {
    newQuantity = positiveNumber(body.newQuantity);
    ensure(newQuantity, '00304');
  }
  const groupId = requireLeader(ctx, '00288', '00307');
  try {
    const listId = await withTx(async (db) => {
      const task = (await db.query('SELECT * FROM shopping_tasks WHERE id = $1 AND group_id = $2 FOR UPDATE', [taskId, groupId]))
        .rows[0];
      ensure(task, '00306');
      ensure(task.status === 'pending', '00514');
      const sets = [];
      const params = [taskId];
      if (isPresent(body.newFoodName)) {
        const food = await findFoodByName(db, groupId, body.newFoodName);
        ensure(food, '00308');
        params.push(food.id);
        sets.push(`food_id = $${params.length}`);
      }
      if (newQuantity) {
        params.push(newQuantity);
        sets.push(`quantity = $${params.length}`);
      }
      await db.query(`UPDATE shopping_tasks SET ${sets.join(', ')} WHERE id = $1`, params);
      await audit(db, ctx, 'shopping.update_task', 'shopping_task', taskId, { newFoodName: body.newFoodName, newQuantity });
      return task.list_id;
    });
    const task = (await query(`${TASK_SELECT} WHERE t.id = $1`, [taskId])).rows[0];
    return result('00312', { task: toTaskDto(task), listId });
  } catch (err) {
    if (err.code === '23505') throw new AppError('00309');
    throw err;
  }
}

/** DELETE shopping/task/ {taskId} */
export async function deleteTask(ctx, body = {}) {
  ensure(body && Object.keys(body).length, '00293');
  const taskId = toId(body.taskId);
  ensure(taskId, '00294');
  const groupId = requireLeader(ctx, '00288', '00297');
  await withTx(async (db) => {
    const del = await db.query('DELETE FROM shopping_tasks WHERE id = $1 AND group_id = $2 RETURNING list_id', [taskId, groupId]);
    ensure(del.rowCount, '00296');
    await audit(db, ctx, 'shopping.delete_task', 'shopping_task', taskId, { listId: del.rows[0].list_id });
  });
  return result('00299');
}

// ===================== UC04 - Xác nhận mua & nhập tủ lạnh =====================

function normalizePurchaseItems(raw, tz) {
  const items = maybeJson(raw);
  ensure(Array.isArray(items) && items.length > 0 && items.length <= 100, '00513');
  const seen = new Set();
  return items.map((it) => {
    const taskId = toId(it?.taskId);
    ensure(taskId && !seen.has(taskId), '00513', { taskId: it?.taskId ?? null });
    seen.add(taskId);
    let boughtQuantity = null;
    if (it.boughtQuantity !== undefined && it.boughtQuantity !== null && it.boughtQuantity !== '') {
      boughtQuantity = positiveNumber(it.boughtQuantity);
      ensure(boughtQuantity, '00513', { taskId, field: 'boughtQuantity' });
    }
    const addToFridge = !(it.addToFridge === false || it.addToFridge === 'false');
    let useWithin = null;
    let location = null;
    if (addToFridge) {
      useWithin = parseUseWithin(it.useWithin, tz);
      ensure(useWithin, '00518', { taskId });
      location = it.location ?? 'cool';
      ensure(LOCATIONS.includes(location), '00517', { taskId });
    }
    const note = optionalNote(it.note, 500);
    ensure(note.ok, '00513', { taskId, field: 'note' });
    return {
      taskId, boughtQuantity, addToFridge, useWithin, location, note: note.value,
      // Dạng gốc dùng để băm => gửi lại cùng nội dung luôn ra cùng hash (kể cả useWithin dạng "số ngày")
      raw: { taskId, boughtQuantity, addToFridge, useWithin: it.useWithin ?? null, location, note: note.value },
    };
  });
}

/**
 * POST shopping/purchase/  (header Idempotency-Key)
 * body: { listId, items: [{ taskId, boughtQuantity?, addToFridge?=true, useWithin, location?, note? }] }
 *
 * Trong MỘT giao dịch: ghi khóa chống lặp -> khóa danh sách & nhiệm vụ -> đánh dấu đã mua ->
 * ghi lịch sử mua -> cộng tồn tủ lạnh -> lưu kết quả vào khóa. Gửi lại cùng khóa => trả kết quả cũ,
 * không cộng tồn lần nữa (NFR09, NFR10).
 */
export async function confirmPurchase(ctx, body = {}, idempotencyKey) {
  const key = typeof idempotencyKey === 'string' ? idempotencyKey.trim() : '';
  ensure(key.length >= 8 && key.length <= 100, '00511');
  const listId = toId(body.listId);
  ensure(listId, '00277');
  const items = normalizePurchaseItems(body.items, ctx.timezone);
  const groupId = requireMember(ctx, '00288');
  const requestHash = crypto
    .createHash('sha256')
    .update(JSON.stringify({ listId, items: items.map((i) => i.raw) }))
    .digest('hex');

  const out = await withTx(async (db) => {
    const claimed = await db.query(
      `INSERT INTO idempotency_keys (user_id, key, endpoint, request_hash) VALUES ($1, $2, 'shopping.purchase', $3)
       ON CONFLICT (user_id, key) DO NOTHING RETURNING key`,
      [ctx.userId, key, requestHash],
    );
    if (!claimed.rowCount) {
      // Khóa đã được xử lý (yêu cầu song song cùng khóa sẽ chờ giao dịch trước commit rồi tới đây)
      const prev = (await db.query('SELECT * FROM idempotency_keys WHERE user_id = $1 AND key = $2', [ctx.userId, key])).rows[0];
      ensure(prev && prev.endpoint === 'shopping.purchase' && prev.request_hash === requestHash && prev.response, '00512');
      return { response: prev.response, replayed: true };
    }

    const list = (
      await db.query('SELECT id, assigned_user_id FROM shopping_lists WHERE id = $1 AND group_id = $2 FOR UPDATE', [listId, groupId])
    ).rows[0];
    ensure(list, '00283');
    ensure(ctx.groupRole === 'admin' || list.assigned_user_id === ctx.userId, '00515');

    const { rows: tasks } = await db.query(
      `SELECT t.id, t.quantity, t.status, f.id AS food_id, f.name AS food_name, un.name AS unit_name, c.name AS category_name
         FROM shopping_tasks t
         JOIN foods f ON f.id = t.food_id
         JOIN units un ON un.id = f.unit_id
         JOIN categories c ON c.id = f.category_id
        WHERE t.list_id = $1 AND t.id = ANY($2::bigint[])
        FOR UPDATE OF t`,
      [listId, items.map((i) => i.taskId)],
    );
    const byId = new Map(tasks.map((t) => [t.id, t]));

    const results = [];
    for (const it of items) {
      const task = byId.get(it.taskId);
      ensure(task, '00513', { taskId: it.taskId, reason: 'Nhiệm vụ không thuộc danh sách' });
      ensure(task.status === 'pending', '00514', { taskId: it.taskId });
      const qty = it.boughtQuantity ?? task.quantity;
      await db.query(
        `UPDATE shopping_tasks SET status = 'bought', bought_quantity = $2, bought_by = $3, bought_at = now() WHERE id = $1`,
        [task.id, qty, ctx.userId],
      );
      await recordStockEvent(db, {
        groupId, food: task, type: 'purchase', quantity: qty, actorUserId: ctx.userId, shoppingTaskId: task.id, note: it.note,
      });
      let fridge = null;
      if (it.addToFridge) {
        // Một mục tủ lạnh / thực phẩm: cộng dồn số lượng, giữ hạn sớm nhất để nhắc hạn an toàn
        const f = await db.query(
          `INSERT INTO fridge_items (group_id, food_id, quantity, use_within, location, note)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (group_id, food_id) DO UPDATE SET
             quantity   = fridge_items.quantity + EXCLUDED.quantity,
             use_within = LEAST(fridge_items.use_within, EXCLUDED.use_within),
             note       = COALESCE(EXCLUDED.note, fridge_items.note),
             version    = fridge_items.version + 1,
             updated_at = now()
           RETURNING id, quantity, use_within`,
          [groupId, task.food_id, qty, it.useWithin, it.location, it.note],
        );
        fridge = { itemId: f.rows[0].id, quantity: f.rows[0].quantity, useWithin: f.rows[0].use_within };
      }
      results.push({ taskId: task.id, foodName: task.food_name, boughtQuantity: qty, unit: task.unit_name, fridge });
    }
    await db.query('UPDATE shopping_lists SET updated_at = now() WHERE id = $1', [listId]);
    await audit(db, ctx, 'shopping.purchase', 'shopping_list', listId, { tasks: results.map((r) => r.taskId) });

    const response = { listId, results };
    await db.query('UPDATE idempotency_keys SET response = $3, status_code = 200 WHERE user_id = $1 AND key = $2', [
      ctx.userId,
      key,
      JSON.stringify(response),
    ]);
    return { response, replayed: false };
  });

  if (!out.replayed) triggerExpiryScan(groupId);
  return result('00510', { ...out.response, replayed: out.replayed, list: await loadList(groupId, listId) });
}
