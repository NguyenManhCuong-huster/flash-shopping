import crypto from 'node:crypto';
import { query, withTx } from '../../db/pool.js';
import { AppError, result } from '../../common/errors.js';
import { messageOf } from '../../common/codes.js';
import {
  cleanString, ensure, isPresent, LOCATIONS, maybeJson, optionalNote, pageMeta, parsePage, positiveNumber, toId,
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

const ITEM_SELECT = `
  SELECT t.id, t.list_id, t.quantity, t.status, t.purchased_quantity, t.purchased_at, t.purchased_by,
         bu.name AS purchased_by_name,
         f.id AS food_id, f.name AS food_name, f.image_url AS food_image_url,
         c.id AS category_id, c.name AS category_name, un.id AS unit_id, un.name AS unit_name
    FROM shopping_items t
    JOIN foods f ON f.id = t.food_id
    JOIN categories c ON c.id = f.category_id
    JOIN units un ON un.id = f.unit_id
    LEFT JOIN users bu ON bu.id = t.purchased_by`;

const toItemDto = (t) => ({
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
  purchasedQuantity: t.purchased_quantity,
  purchasedAt: t.purchased_at,
  purchasedBy: t.purchased_by ? { id: t.purchased_by, name: t.purchased_by_name } : null,
});

function toListDto(l, items = []) {
  const purchased = items.filter((t) => t.status !== 'pending').length;
  return {
    id: l.id,
    name: l.name,
    note: l.note,
    createdAt: l.created_at,
    completedAt: l.completed_at,
    assignedTo: l.assigned_user_id
      ? { id: l.assigned_user_id, name: l.assigned_name, username: l.assigned_username, imageUrl: l.assigned_image }
      : null,
    createdBy: l.created_by,
    updatedAt: l.updated_at,
    items: items.map(toItemDto),
    progress: { total: items.length, purchased, done: items.length > 0 && purchased === items.length },
  };
}

async function withItems(lists) {
  if (!lists.length) return [];
  const { rows } = await query(`${ITEM_SELECT} WHERE t.list_id = ANY($1::bigint[]) ORDER BY t.status DESC, t.id`, [
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
  return rows[0] ? (await withItems(rows))[0] : null;
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
  ensure(isPresent(body.name), '00005');
  const name = cleanString(body.name, { min: 1, max: 150 });
  ensure(name, '00239');
  const note = optionalNote(body.note);
  ensure(note.ok, '00193');
  const groupId = requireLeader(ctx, '00096', '00104');

  const id = await withTx(async (db) => {
    const assignee = isPresent(body.assignToUsername)
      ? await resolveAssignee(db, groupId, body.assignToUsername, '00007', '00104')
      : null;
    const { rows } = await db.query(
      `INSERT INTO shopping_lists (group_id, assigned_user_id, name, note, created_by)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [groupId, assignee, name, note.value, ctx.userId],
    );
    await audit(db, ctx, 'shopping.create_list', 'shopping_list', rows[0].id, { name, assignee });
    return rows[0].id;
  });
  return result('00249', { listId: id, list: await loadList(groupId, id) });
}

/** PUT shopping/ - Sửa tên/người được giao/ghi chú. newAssignToUsername = "" để bỏ giao. */
export async function updateList(ctx, body = {}) {
  const listId = toId(body.listId);
  ensure(listId, '00251');
  const keys = ['newName', 'newAssignToUsername', 'newNote'];
  ensure(keys.some((k) => body[k] !== undefined), '00005');
  let newName = null;
  if (body.newName !== undefined) {
    newName = cleanString(body.newName, { min: 1, max: 150 });
    ensure(newName, '00253');
  }
  if (body.newAssignToUsername !== undefined) ensure(typeof body.newAssignToUsername === 'string', '00254');
  const newNote = body.newNote !== undefined ? optionalNote(body.newNote) : null;
  if (newNote) ensure(newNote.ok, '00193');
  const groupId = requireLeader(ctx, '00096', '00104');

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
    if (body.newAssignToUsername !== undefined) {
      const assignee = body.newAssignToUsername.trim() === ''
        ? null
        : await resolveAssignee(db, groupId, body.newAssignToUsername, '00007', '00104');
      push('assigned_user_id', assignee);
    }
    await db.query(`UPDATE shopping_lists SET ${sets.join(', ')} WHERE id = $1`, params);
    await audit(db, ctx, 'shopping.update_list', 'shopping_list', listId, {
      newName, newAssignToUsername: body.newAssignToUsername,
    });
  });
  return result('00266', { list: await loadList(groupId, listId) });
}

/** DELETE shopping/ {listId} */
export async function deleteList(ctx, body = {}) {
  ensure(body && Object.keys(body).length, '00005');
  const listId = toId(body.listId);
  ensure(listId, '00251');
  const groupId = requireLeader(ctx, '00096', '00104');
  await withTx(async (db) => {
    const del = await db.query('DELETE FROM shopping_lists WHERE id = $1 AND group_id = $2 RETURNING name', [listId, groupId]);
    ensure(del.rowCount, '00260');
    await audit(db, ctx, 'shopping.delete_list', 'shopping_list', listId, { name: del.rows[0].name });
  });
  return result('00275');
}

/** GET shopping/item/?from&to&status=open|done&assignedToMe=true&page&limit - Danh sách kèm mặt hàng. */
export async function listLists(ctx, q = {}) {
  const groupId = requireMember(ctx, '00096');
  const p = parsePage(q, { defaultLimit: 20 });
  const params = [groupId];
  const where = ['sl.group_id = $1'];
  const add = (sql, v) => {
    params.push(v);
    where.push(sql.replaceAll('?', `$${params.length}`));
  };
  if (q.assignedToMe === 'true') add('sl.assigned_user_id = ?', ctx.userId);
  if (q.status === 'open') where.push(`(NOT EXISTS (SELECT 1 FROM shopping_items t WHERE t.list_id = sl.id)
                                       OR EXISTS (SELECT 1 FROM shopping_items t WHERE t.list_id = sl.id AND t.status = 'pending'))`);
  if (q.status === 'done') where.push(`EXISTS (SELECT 1 FROM shopping_items t WHERE t.list_id = sl.id)
                                       AND NOT EXISTS (SELECT 1 FROM shopping_items t WHERE t.list_id = sl.id AND t.status = 'pending')`);
  const w = where.join(' AND ');
  const total = (await query(`SELECT count(*)::int AS n FROM shopping_lists sl WHERE ${w}`, params)).rows[0].n;
  const { rows } = await query(
    `${LIST_SELECT} WHERE ${w} ORDER BY sl.created_at DESC, sl.id DESC LIMIT ${p.limit} OFFSET ${p.offset}`,
    params,
  );
  return result('00292', { lists: await withItems(rows), ...pageMeta(p, total) });
}

/** GET shopping/:listId/ */
export async function getList(ctx, rawId) {
  const listId = toId(rawId);
  ensure(rawId !== undefined, '00022');
  ensure(listId, '00022');
  const groupId = requireMember(ctx, '00096');
  const list = await loadList(groupId, listId);
  ensure(list, '00260');
  return result('00570', { list });
}

// ===================== Mặt hàng cần mua (shopping_items) =====================

/**
 * POST shopping/item/ {listId, items:[{foodName, quantity}]}
 * Kiểm tra từng mục; lưu các mục hợp lệ, trả rõ mục lỗi (UC03 bước 5, 5a).
 */
export async function createItems(ctx, body = {}) {
  ensure(body.listId !== undefined || body.items !== undefined, '00005');
  const listId = toId(body.listId);
  ensure(listId, '00251');
  const items = maybeJson(body.items);
  ensure(Array.isArray(items) && items.length > 0 && items.length <= 100, '00278');
  const groupId = requireLeader(ctx, '00096', '00104');

  const out = await withTx(async (db) => {
    const list = (await db.query('SELECT id FROM shopping_lists WHERE id = $1 AND group_id = $2 FOR UPDATE', [listId, groupId]))
      .rows[0];
    ensure(list, '00260');
    const created = [];
    const failed = [];
    for (const [index, t] of items.entries()) {
      const foodName = typeof t?.foodName === 'string' ? t.foodName.trim() : '';
      const quantity = positiveNumber(t?.quantity);
      if (!foodName || !quantity) {
        failed.push({ index, foodName: t?.foodName ?? null, code: '00279' });
        continue;
      }
      const food = await findFoodByName(db, groupId, foodName);
      if (!food) {
        failed.push({ index, foodName, code: '00167' });
        continue;
      }
      const ins = await db.query(
        `INSERT INTO shopping_items (list_id, group_id, food_id, quantity) VALUES ($1, $2, $3, $4)
         ON CONFLICT (list_id, food_id) DO NOTHING RETURNING id`,
        [listId, groupId, food.id, quantity],
      );
      if (!ins.rowCount) {
        failed.push({ index, foodName, code: '00151' });
        continue;
      }
      created.push({ index, itemId: ins.rows[0].id, foodName: food.name, quantity });
    }
    if (created.length) {
      await db.query('UPDATE shopping_lists SET updated_at = now(), completed_at = NULL WHERE id = $1', [listId]);
      await audit(db, ctx, 'shopping.create_items', 'shopping_list', listId, { count: created.length });
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

/** PUT shopping/item/ {itemId, newFoodName?, newQuantity?} */
export async function updateItem(ctx, body = {}) {
  ensure(body && Object.keys(body).length, '00005');
  const itemId = toId(body.itemId);
  ensure(itemId, '00294');
  ensure(isPresent(body.newFoodName) || isPresent(body.newQuantity), '00005');
  if (body.newFoodName !== undefined && body.newFoodName !== '') ensure(cleanString(body.newFoodName, { max: 150 }), '00148');
  let newQuantity = null;
  if (isPresent(body.newQuantity)) {
    newQuantity = positiveNumber(body.newQuantity);
    ensure(newQuantity, '00192');
  }
  const groupId = requireLeader(ctx, '00096', '00104');
  try {
    const listId = await withTx(async (db) => {
      const item = (await db.query('SELECT * FROM shopping_items WHERE id = $1 AND group_id = $2 FOR UPDATE', [itemId, groupId]))
        .rows[0];
      ensure(item, '00296');
      ensure(item.status === 'pending', '00514');
      const sets = [];
      const params = [itemId];
      if (isPresent(body.newFoodName)) {
        const food = await findFoodByName(db, groupId, body.newFoodName);
        ensure(food, '00167');
        params.push(food.id);
        sets.push(`food_id = $${params.length}`);
      }
      if (newQuantity) {
        params.push(newQuantity);
        sets.push(`quantity = $${params.length}`);
      }
      await db.query(`UPDATE shopping_items SET ${sets.join(', ')} WHERE id = $1`, params);
      await audit(db, ctx, 'shopping.update_item', 'shopping_item', itemId, { newFoodName: body.newFoodName, newQuantity });
      return item.list_id;
    });
    const item = (await query(`${ITEM_SELECT} WHERE t.id = $1`, [itemId])).rows[0];
    return result('00312', { item: toItemDto(item), listId });
  } catch (err) {
    if (err.code === '23505') throw new AppError('00151');
    throw err;
  }
}

/** DELETE shopping/item/ {itemId} */
export async function deleteItem(ctx, body = {}) {
  ensure(body && Object.keys(body).length, '00005');
  const itemId = toId(body.itemId);
  ensure(itemId, '00294');
  const groupId = requireLeader(ctx, '00096', '00104');
  await withTx(async (db) => {
    const del = await db.query('DELETE FROM shopping_items WHERE id = $1 AND group_id = $2 RETURNING list_id', [itemId, groupId]);
    ensure(del.rowCount, '00296');
    await audit(db, ctx, 'shopping.delete_item', 'shopping_item', itemId, { listId: del.rows[0].list_id });
  });
  return result('00299');
}

// ===================== UC04 - Xác nhận mua / nhập tủ lạnh =====================

function normalizePurchaseItems(raw, tz) {
  const items = maybeJson(raw);
  ensure(Array.isArray(items) && items.length > 0 && items.length <= 100, '00513');
  const seen = new Set();
  return items.map((it) => {
    const itemId = toId(it?.itemId);
    ensure(itemId && !seen.has(itemId), '00513', { itemId: it?.itemId ?? null });
    seen.add(itemId);
    let purchasedQuantity = null;
    if (it.purchasedQuantity !== undefined && it.purchasedQuantity !== null && it.purchasedQuantity !== '') {
      purchasedQuantity = positiveNumber(it.purchasedQuantity);
      ensure(purchasedQuantity, '00513', { itemId, field: 'purchasedQuantity' });
    }
    const note = optionalNote(it.note, 500);
    ensure(note.ok, '00513', { itemId, field: 'note' });
    return {
      itemId, purchasedQuantity, note: note.value,
      raw: { itemId, purchasedQuantity, note: note.value },
    };
  });
}

/**
 * POST shopping/purchase/  (header Idempotency-Key)
 * body: { listId, items: [{ itemId, purchasedQuantity?, note? }] }
 *
 * Trong MỘT giao dịch: ghi khóa chống lặp -> khóa danh sách & nhiệm vụ -> đánh dấu đã mua ->
 * ghi lịch sử mua -> tạo thông báo -> lưu kết quả vào khóa.
 */
export async function confirmPurchase(ctx, body = {}, idempotencyKey) {
  const key = typeof idempotencyKey === 'string' ? idempotencyKey.trim() : '';
  ensure(key.length >= 8 && key.length <= 100, '00511');
  const listId = toId(body.listId);
  ensure(listId, '00251');
  const items = normalizePurchaseItems(body.items, ctx.timezone);
  const groupId = requireMember(ctx, '00096');
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
    ensure(list, '00260');
    ensure(ctx.groupRole === 'admin' || list.assigned_user_id === ctx.userId, '00515');

    const { rows: dbItems } = await db.query(
      `SELECT t.id, t.quantity, t.status, f.id AS food_id, f.name AS food_name, un.name AS unit_name, c.name AS category_name
         FROM shopping_items t
         JOIN foods f ON f.id = t.food_id
         JOIN units un ON un.id = f.unit_id
         JOIN categories c ON c.id = f.category_id
        WHERE t.list_id = $1 AND t.id = ANY($2::bigint[])
        FOR UPDATE OF t`,
      [listId, items.map((i) => i.itemId)],
    );
    const byId = new Map(dbItems.map((t) => [t.id, t]));

    const results = [];
    for (const it of items) {
      const item = byId.get(it.itemId);
      ensure(item, '00513', { itemId: it.itemId, reason: 'Nhiệm vụ không thuộc danh sách' });
      ensure(item.status === 'pending', '00514', { itemId: it.itemId });
      const qty = it.purchasedQuantity ?? item.quantity;
      await db.query(
        `UPDATE shopping_items SET status = 'bought', purchased_quantity = $2, purchased_by = $3, purchased_at = now() WHERE id = $1`,
        [item.id, qty, ctx.userId],
      );
      await recordStockEvent(db, {
        groupId, food: item, type: 'purchase', quantity: qty, actorUserId: ctx.userId, shoppingItemId: item.id, note: it.note,
      });
      results.push({ itemId: item.id, foodName: item.food_name, purchasedQuantity: qty, unit: item.unit_name });
    }
    await db.query(
      'UPDATE shopping_lists SET completed_at = NULL, updated_at = now() WHERE id = $1',
      [listId],
    );
    const pending = (await db.query(
      `SELECT count(*)::int AS count FROM shopping_items WHERE list_id = $1 AND status = 'pending'`,
      [listId],
    )).rows[0].count;
    if (pending === 0) {
      await db.query('UPDATE shopping_lists SET completed_at = COALESCE(completed_at, now()) WHERE id = $1', [listId]);
      const members = await db.query('SELECT user_id FROM group_members WHERE group_id = $1', [groupId]);
      for (const member of members.rows) {
        await db.query(
          `INSERT INTO notifications (user_id, group_id, type, dedupe_key, title, body, data)
           VALUES ($1, $2, 'purchase_complete', $3, $4, $5, $6)
           ON CONFLICT (user_id, type, dedupe_key) DO NOTHING`,
          [member.user_id, groupId, `shopping-list:${listId}`,
            '🛒 Đơn mua sắm mới đã hoàn tất!',
            'Bạn vừa hoàn thành một phiên mua sắm mới. Hãy kiểm tra và thêm các sản phẩm vừa mua vào tủ lạnh ngay nhé!',
            JSON.stringify({ listId, screen: 'shopping_list' })],
        );
      }
    }
    await audit(db, ctx, 'shopping.purchase', 'shopping_list', listId, { items: results.map((r) => r.itemId) });

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

/** POST fridge/from-purchase/ - Nhập từng item đã mua vào tủ lạnh. */
export async function addPurchasedItems(ctx, body = {}, idempotencyKey) {
  const key = typeof idempotencyKey === 'string' ? idempotencyKey.trim() : '';
  ensure(key.length >= 8 && key.length <= 100, '00511');
  const listId = toId(body.listId);
  ensure(listId, '00251');
  const rawItems = maybeJson(body.items);
  ensure(Array.isArray(rawItems) && rawItems.length > 0 && rawItems.length <= 100, '00513');
  const groupId = requireMember(ctx, '00096');
  const items = rawItems.map((it) => {
    const itemId = toId(it?.itemId);
    const useWithin = parseUseWithin(it?.useWithin, ctx.timezone);
    const location = it?.location ?? 'cool';
    const note = optionalNote(it?.note, 500);
    ensure(itemId && useWithin && LOCATIONS.includes(location) && note.ok, '00513', { itemId });
    return { itemId, useWithin, location, note: note.value };
  });
  const requestHash = crypto.createHash('sha256').update(JSON.stringify({ listId, items })).digest('hex');
  const out = await withTx(async (db) => {
    const claim = await db.query(
      `INSERT INTO idempotency_keys (user_id, key, endpoint, request_hash)
       VALUES ($1, $2, 'fridge.from-purchase', $3)
       ON CONFLICT (user_id, key) DO NOTHING RETURNING key`,
      [ctx.userId, key, requestHash],
    );
    if (!claim.rowCount) {
      const prev = (await db.query('SELECT * FROM idempotency_keys WHERE user_id = $1 AND key = $2', [ctx.userId, key])).rows[0];
      ensure(prev?.endpoint === 'fridge.from-purchase' && prev.request_hash === requestHash && prev.response, '00512');
      return { response: prev.response, replayed: true };
    }
    const { rows: dbItems } = await db.query(
      `SELECT t.*, f.name AS food_name, un.name AS unit_name, sl.completed_at
       FROM shopping_items t
       JOIN shopping_lists sl ON sl.id = t.list_id
       JOIN foods f ON f.id = t.food_id JOIN units un ON un.id = f.unit_id
       WHERE t.list_id = $1 AND t.group_id = $2 AND t.id = ANY($3::bigint[]) FOR UPDATE OF t`,
      [listId, groupId, items.map((i) => i.itemId)],
    );
    const byId = new Map(dbItems.map((t) => [t.id, t]));
    const results = [];
    for (const it of items) {
      const item = byId.get(it.itemId);
      ensure(item && item.status === 'bought', '00514', { itemId: it.itemId });
      const inserted = await db.query(
        `INSERT INTO fridge_items (
           group_id, food_id, shopping_item_id, batch_code, quantity, use_within, location, note, purchased_at
         )
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING id, quantity, use_within`,
        [groupId, item.food_id, item.id, `shopping-list:${listId}`, item.purchased_quantity ?? item.quantity,
          it.useWithin, it.location, it.note, item.purchased_at ?? item.completed_at],
      );
      await db.query(`UPDATE shopping_items SET status = 'in_fridge' WHERE id = $1`, [item.id]);
      await recordStockEvent(db, {
        groupId, food: item, type: 'add', quantity: item.purchased_quantity ?? item.quantity,
        actorUserId: ctx.userId, shoppingItemId: item.id, note: it.note,
      });
      results.push({ itemId: item.id, fridgeItemId: inserted.rows[0].id, foodName: item.food_name,
        quantity: inserted.rows[0].quantity, useWithin: inserted.rows[0].use_within, unit: item.unit_name });
    }
    const response = { listId, results };
    await db.query('UPDATE idempotency_keys SET response = $3, status_code = 200 WHERE user_id = $1 AND key = $2',
      [ctx.userId, key, JSON.stringify(response)]);
    return { response, replayed: false };
  });
  if (!out.replayed) triggerExpiryScan(groupId);
  return result('00202', { ...out.response, replayed: out.replayed, list: await loadList(groupId, listId) });
}
