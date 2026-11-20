import crypto from 'node:crypto';
import { query, withTx } from '../../db/pool.js';
import { AppError, result } from '../../common/errors.js';
import { messageOf } from '../../common/codes.js';
import {
  cleanString, ensure, isPresent, LOCATIONS, maybeJson, optionalNote, pageMeta, parsePage, positiveNumber, toId,
} from '../../common/validate.js';
import { requireLeader, requireMember } from '../../common/permissions.js';
import { audit } from '../../common/audisi.js';
import { findFoodByName } from '../food/food.repo.js';
import { recordStockEvent } from '../stock/stock.repo.js';
import { parseUseWithin } from '../fridge/fridge.service.js';
import { triggerExpiryScan } from '../notification/expiry.job.js';

const SESSION_SELECT = `
  SELECT ss.*, au.name AS assigned_name, au.username AS assigned_username, au.image_url AS assigned_image
    FROM shopping_sessions ss
    LEFT JOIN users au ON au.id = ss.assigned_user_id`;

const ITEM_SELECT = `
  SELECT si.id, si.session_id, si.quantity, si.status, si.purchased_quantity, si.purchased_at, si.purchased_by,
         bu.name AS purchased_by_name,
         f.id AS food_id, f.name AS food_name, f.image_url AS food_image_url,
         c.id AS category_id, c.name AS category_name, un.id AS unit_id, un.name AS unit_name
    FROM shopping_items si
    JOIN foods f ON f.id = si.food_id
    JOIN categories c ON c.id = f.category_id
    JOIN units un ON un.id = f.unit_id
    LEFT JOIN users bu ON bu.id = si.purchased_by`;

const mapShoppingItemToDto = (si) => ({
  id: si.id,
  sessionId: si.session_id,
  food: {
    id: si.food_id,
    name: si.food_name,
    imageUrl: si.food_image_url,
    category: { id: si.category_id, name: si.category_name },
    unit: { id: si.unit_id, name: si.unit_name },
  },
  quantity: si.quantity,
  status: si.status,
  purchasedQuantity: si.purchased_quantity,
  purchasedAt: si.purchased_at,
  purchasedBy: si.purchased_by ? { id: si.purchased_by, name: si.purchased_by_name } : null,
});

function mapShoppingSessionToDto(ss, items = []) {
  const purchased = items.filter((si) => si.status !== 'pending').length;
  return {
    id: ss.id,
    name: ss.name,
    note: ss.note,
    createdBy: ss.created_by,
    createdAt: ss.created_at,
    updatedAt: ss.updated_at,
    completedAt: ss.completed_at,
    assignedTo: { id: ss.assigned_user_id, name: ss.assigned_name, username: ss.assigned_username, imageUrl: ss.assigned_image },
    items: items.map(mapShoppingItemToDto),
    progress: { total: items.length, purchased, done: items.length > 0 && purchased === items.length },
  };
}

async function getSessionsWithItems(sessions) {
  if (!sessions.length) return [];
  const { rows } = await query(`${ITEM_SELECT} WHERE si.session_id = ANY($1::bigint[]) ORDER BY si.status DESC, si.id`, [
    sessions.map((s) => s.id),
  ]);
  const bySession = new Map();
  for (const item of rows) {
    if (!bySession.has(item.session_id)) bySession.set(item.session_id, []);
    bySession.get(item.session_id).push(item);
  }
  return sessions.map((s) => mapShoppingSessionToDto(s, bySession.get(s.id) ?? []));
}

export async function getShoppingSessionById(groupId, sessionId) {
  const { rows } = await query(`${SESSION_SELECT} WHERE ss.id = $1 AND ss.group_id = $2`, [sessionId, groupId]);
  return rows[0] ? (await getSessionsWithItems(rows))[0] : null;
}

/** Người được giao phải tồn tại và thuộc cùng nhóm (include bắt buộc của UC03). */
async function resolveShoppingAssignee(db, groupId, username, notFoundCode, otherGroupCode) {
  const u = (await db.query('SELECT id FROM users WHERE username = $1', [String(username).trim()])).rows[0];
  ensure(u, notFoundCode);
  const m = await db.query('SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2', [groupId, u.id]);
  ensure(m.rowCount, otherGroupCode);
  return u.id;
}

// ===================== Phiên mua sắm  (shopping_sessions)=====================

/** POST shopping/sessions - Trưởng nhóm tạo danh sách, có thể giao cho thành viên. */
export async function createShoppingSession(ctx, body = {}) {
  ensure(isPresent(body.name), '00005');
  const name = cleanString(body.name, { min: 1, max: 150 });
  ensure(name, '00239');
  const note = optionalNote(body.note);
  ensure(note.ok, '00193');
  const groupId = requireLeader(ctx, '00096', '00104');

  const id = await withTx(async (db) => {
    const assignee = await resolveShoppingAssignee(db, groupId, body.assignToUsername, '00007', '00104');
    const { rows } = await db.query(
      `INSERT INTO shopping_sessions (group_id, assigned_user_id, name, note, created_by)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [groupId, assignee, name, note.value, ctx.userId],
    );
    await audit(db, ctx, 'shopping.create_session', 'shopping_session', rows[0].id, { name, assignee });
    return rows[0].id;
  });
  return result('00249', { sessionId: id, session: await getShoppingSessionById(groupId, id) });
}

/** PATCH shopping/sessions/:sessionId - Sửa tên/người được giao/ghi chú. newAssignToUsername = "" để bỏ giao. */
export async function updateShoppingSession(ctx, body = {}) {
  const sessionId = toId(body.sessionId);
  ensure(sessionId, '00251');
  const keys = ['newName', 'newAssignToUsername', 'newNote'];
  ensure(keys.some((k) => body[k] !== undefined), '00005');
  let newName = null;
  if (body.newName !== undefined) {
    newName = cleanString(body.newName, { min: 1, max: 150 });
    ensure(newName, '00253');
  }
  if (body.newAssignToUsername !== undefined) ensure(typeof body.newAssignToUsername === 'string' && body.newAssignToUsername.trim() !== '', '00254');
  const newNote = body.newNote !== undefined ? optionalNote(body.newNote) : null;
  if (newNote) ensure(newNote.ok, '00193');
  const groupId = requireLeader(ctx, '00096', '00104');

  await withTx(async (db) => {
    const cur = (await db.query('SELECT id FROM shopping_sessions WHERE id = $1 AND group_id = $2 FOR UPDATE', [sessionId, groupId]))
      .rows[0];
    ensure(cur, '00260');
    const sets = ['updated_at = now()'];
    const params = [sessionId];
    const push = (col, v) => {
      params.push(v);
      sets.push(`${col} = $${params.length}`);
    };
    if (newName !== null) push('name', newName);
    if (newNote !== null) push('note', newNote.value);
    if (body.newAssignToUsername !== undefined) {
      const assignee = await resolveShoppingAssignee(db, groupId, body.newAssignToUsername, '00007', '00104');
      push('assigned_user_id', assignee);
    }
    await db.query(`UPDATE shopping_sessions SET ${sets.join(', ')} WHERE id = $1`, params);
    await audit(db, ctx, 'shopping.update_session', 'shopping_session', sessionId, {
      newName, newAssignToUsername: body.newAssignToUsername, newNote: newNote?.value,
    });
  });
  return result('00266', { session: await getShoppingSessionById(groupId, sessionId) });
}

/** DELETE shopping/sessions/:sessionId */
export async function deleteShoppingSession(ctx, body = {}) {
  ensure(body && Object.keys(body).length, '00005');
  const sessionId = toId(body.sessionId);
  ensure(sessionId, '00251');
  const groupId = requireLeader(ctx, '00096', '00104');
  await withTx(async (db) => {
    const del = await db.query('DELETE FROM shopping_sessions WHERE id = $1 AND group_id = $2 RETURNING name', [sessionId, groupId]);
    ensure(del.rowCount, '00260');
    await audit(db, ctx, 'shopping.delete_session', 'shopping_session', sessionId, { name: del.rows[0].name });
  });
  return result('00275');
}

/** GET shopping/sessions/?from&to&status=open|done&assignedToMe=true&page&limit - Danh sách kèm mặt hàng. */
export async function listShoppingSessions(ctx, q = {}) {
  const groupId = requireMember(ctx, '00096');
  const p = parsePage(q, { defaultLimit: 20 });
  const params = [groupId];
  const where = ['ss.group_id = $1'];
  const add = (sql, v) => {
    params.push(v);
    where.push(sql.replaceAll('?', `$${params.length}`));
  };
  if (q.assignedToMe === 'true') add('ss.assigned_user_id = ?', ctx.userId);
  if (q.status === 'open') where.push(`(NOT EXISTS (SELECT 1 FROM shopping_items si WHERE si.session_id = ss.id)
                                       OR EXISTS (SELECT 1 FROM shopping_items si WHERE si.session_id = ss.id AND si.status = 'pending'))`);
  if (q.status === 'done') where.push(`EXISTS (SELECT 1 FROM shopping_items si WHERE si.session_id = ss.id)
                                       AND NOT EXISTS (SELECT 1 FROM shopping_items si WHERE si.session_id = ss.id AND si.status = 'pending')`);
  const w = where.join(' AND ');
  const total = (await query(`SELECT count(*)::int AS n FROM shopping_sessions ss WHERE ${w}`, params)).rows[0].n;
  const { rows } = await query(
    `${SESSION_SELECT} WHERE ${w} ORDER BY ss.created_at DESC, ss.id DESC LIMIT ${p.limit} OFFSET ${p.offset}`,
    params,
  );
  return result('00292', { sessions: await getSessionsWithItems(rows), ...pageMeta(p, total) });
}



/** GET shopping/sessions/:sessionId */
export async function getShoppingSessionById(ctx, rawId) {
  const sessionId = toId(rawId);
  ensure(rawId !== undefined, '00022');
  ensure(sessionId, '00022');
  const groupId = requireMember(ctx, '00096');
  const session = await getShoppingSessionById(groupId, sessionId);
  ensure(session, '00260');
  return result('00570', { session });
}

// ===================== Mặt hàng cần mua (shopping_items) =====================

/** POST shopping/sessions/:sessionId/items - Tạo mặt hàng cần mua trong phiên. Nếu foodId không có thì phải có foodName + categoryId + unitId. */
export async function createShoppingItem(ctx, body = {}) {
  ensure(body.sessionId !== undefined, '00005');
  const sessionId = toId(body.sessionId);
  ensure(sessionId, '00251');

  const foodId = toId(body.foodId);
  const foodName = typeof body.foodName === 'string' ? body.foodName.trim() : '';
  const quantity = positiveNumber(body.quantity);
  const note = optionalNote(body.note, 500);
  const categoryId = toId(body.categoryId);
  const unitId = toId(body.unitId);

  ensure(quantity, '00192');

  const groupId = requireLeader(ctx, '00096', '00104');

  const itemId = await withTx(async (db) => {
    const session = (await db.query(
      'SELECT id FROM shopping_sessions WHERE id = $1 AND group_id = $2 FOR UPDATE',
      [sessionId, groupId],
    )).rows[0];
    ensure(session, '00260');

    let resolvedFoodId = foodId;
    let resolvedFoodName = foodName;

    if (!resolvedFoodId) {
      ensure(resolvedFoodName, '00148');

      const food = await findFoodByName(db, groupId, resolvedFoodName);
      if (food) {
        resolvedFoodId = food.id;
      } else {
        ensure(categoryId, '00149');
        ensure(unitId, '00150');

        const category = await db.query('SELECT id FROM categories WHERE id = $1', [categoryId]);
        ensure(category.rows[0], '00138');

        const unit = await db.query('SELECT id FROM units WHERE id = $1', [unitId]);
        ensure(unit.rows[0], '00119');

        const inserted = await db.query(
          `INSERT INTO foods (group_id, category_id, unit_id, name, image_url) VALUES ($1, $2, $3, $4, $5) RETURNING id`,
          [groupId, categoryId, unitId, resolvedFoodName, null],
        );
        resolvedFoodId = inserted.rows[0].id;

        await audit(db, ctx, 'food.create', 'food', resolvedFoodId, { name: resolvedFoodName });
      }
    }

    const ins = await db.query(
      `INSERT INTO shopping_items (session_id, group_id, food_id, quantity, note, status, created_at)
       VALUES ($1, $2, $3, $4, $5, 'pending', now()) RETURNING id`,
      [sessionId, groupId, resolvedFoodId, quantity, note.ok ? note.value : null],
    );
    ensure(ins.rowCount, '00151');

    await db.query(
      'UPDATE shopping_sessions SET updated_at = now(), completed_at = NULL WHERE id = $1',
      [sessionId],
    );
    await audit(db, ctx, 'shopping.create_item', 'shopping_session', sessionId, {
      foodId: resolvedFoodId,
      quantity,
    });

    return ins.rows[0].id;
  });

  const item = (await query(`${ITEM_SELECT} WHERE si.id = $1`, [itemId])).rows[0];
  ensure(item, '00151');

  return result('00287', { item: mapShoppingItemToDto(item) });
}

/** PATCH shopping/sessions/:sessionId/items/:itemId - Cập nhật mặt hàng chưa mua */
export async function updateShoppingItem(ctx, body = {}) {
  ensure(body && Objecsi.keys(body).length, '00005');
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
    const sessionId = await withTx(async (db) => {
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
      return item.session_id;
    });
    const item = (await query(`${ITEM_SELECT} WHERE si.id = $1`, [itemId])).rows[0];
    return result('00312', { item: mapShoppingItemToDto(item), sessionId });
  } catch (err) {
    if (err.code === '23505') throw new AppError('00151');
    throw err;
  }
}
/** DELETE shopping/sessions/:sessionId/items/:itemId - Xóa mặt hàng */
export async function deleteShoppingItem(ctx, body = {}) {
  ensure(body && Objecsi.keys(body).length, '00005');
  const itemId = toId(body.itemId);
  ensure(itemId, '00294');
  const groupId = requireLeader(ctx, '00096', '00104');
  await withTx(async (db) => {
    const del = await db.query('DELETE FROM shopping_items WHERE id = $1 AND group_id = $2 RETURNING session_id', [itemId, groupId]);
    ensure(del.rowCount, '00296');
    await audit(db, ctx, 'shopping.delete_item', 'shopping_item', itemId, { sessionId: del.rows[0].session_id });
  });
  return result('00299');
}

// ===================== UC04 - Xác nhận mua / nhập tủ lạnh =====================

function normalizePurchaseItems(raw, tz) {
  const items = maybeJson(raw);
  ensure(Array.isArray(items) && items.length > 0 && items.length <= 100, '00513');
  const seen = new Set();
  return items.map((item) => {
    const itemId = toId(item?.itemId);
    ensure(itemId && !seen.has(itemId), '00513', { itemId: item?.itemId ?? null });
    seen.add(itemId);
    let purchasedQuantity = null;
    if (isPresent(item.purchasedQuantity)) {
      purchasedQuantity = positiveNumber(item.purchasedQuantity);
      ensure(purchasedQuantity, '00513', { itemId, field: 'purchasedQuantity' });
    }
    const note = optionalNote(item.note, 500);
    ensure(note.ok, '00513', { itemId, field: 'note' });
    return {
      itemId, purchasedQuantity, note: note.value,
      raw: { itemId, purchasedQuantity, note: note.value },
    };
  });
}

/**
 * POST shopping/sessions/:sessionId/purchases  (header Idempotency-Key)
 * body: { sessionId, items: [{ itemId, purchasedQuantity?, note? }] }
 *
 * Trong MỘT giao dịch: ghi khóa chống lặp -> khóa danh sách & nhiệm vụ -> đánh dấu đã mua ->
 * ghi lịch sử mua -> tạo thông báo -> lưu kết quả vào khóa.
 */
export async function confirmShoppingPurchase(ctx, body = {}, idempotencyKey) {
  const key = typeof idempotencyKey === 'string' ? idempotencyKey.trim() : '';
  ensure(key.length >= 8 && key.length <= 100, '00511');
  const sessionId = toId(body.sessionId);
  ensure(sessionId, '00251');
  const items = normalizePurchaseItems(body.items, ctx.timezone);
  const groupId = requireMember(ctx, '00096');
  const requestHash = crypto
    .createHash('sha256')
    .update(JSON.stringify({ sessionId, items: items.map((i) => i.raw) }))
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

    const session = (
      await db.query('SELECT id, assigned_user_id FROM shopping_sessions WHERE id = $1 AND group_id = $2 FOR UPDATE', [sessionId, groupId])
    ).rows[0];
    ensure(session, '00260');
    ensure(ctx.groupRole === 'admin' || session.assigned_user_id === ctx.userId, '00515');

    const { rows: dbItems } = await db.query(
      `SELECT si.id, si.quantity, si.status, f.id AS food_id, f.name AS food_name, un.name AS unit_name, c.name AS category_name
         FROM shopping_items si
         JOIN foods f ON f.id = si.food_id
         JOIN units un ON un.id = f.unit_id
         JOIN categories c ON c.id = f.category_id
        WHERE si.session_id = $1 AND si.id = ANY($2::bigint[])
        FOR UPDATE OF si`,
      [sessionId, items.map((item) => item.itemId)],
    );
    const byId = new Map(dbItems.map((t) => [si.id, si]));

    const results = [];
    for (const item of items) {
      const item = byId.get(item.itemId);
      ensure(item, '00513', { itemId: item.itemId, reason: 'Nhiệm vụ không thuộc danh sách' });
      ensure(item.status === 'pending', '00514', { itemId: item.itemId });
      const qty = item.purchasedQuantity ?? item.quantity;
      await db.query(
        `UPDATE shopping_items SET status = 'bought', purchased_quantity = $2, purchased_by = $3, purchased_at = now() WHERE id = $1`,
        [item.id, qty, ctx.userId],
      );
      await recordStockEvent(db, {
        groupId, food: item, type: 'purchase', quantity: qty, actorUserId: ctx.userId, shoppingItemId: item.id, note: item.note,
      });
      results.push({ itemId: item.id, foodName: item.food_name, purchasedQuantity: qty, unit: item.unit_name });
    }
    await db.query(
      'UPDATE shopping_sessions SET completed_at = NULL, updated_at = now() WHERE id = $1',
      [sessionId],
    );
    const pending = (await db.query(
      `SELECT count(*)::int AS count FROM shopping_items WHERE session_id = $1 AND status = 'pending'`,
      [sessionId],
    )).rows[0].count;
    if (pending === 0) {
      await db.query('UPDATE shopping_sessions SET completed_at = COALESCE(completed_at, now()) WHERE id = $1', [sessionId]);
      const members = await db.query('SELECT user_id FROM group_members WHERE group_id = $1', [groupId]);
      for (const member of members.rows) {
        await db.query(
          `INSERT INTO notifications (user_id, group_id, type, dedupe_key, title, body, data)
           VALUES ($1, $2, 'purchase_complete', $3, $4, $5, $6)
           ON CONFLICT (user_id, type, dedupe_key) DO NOTHING`,
          [member.user_id, groupId, `shopping-session:${sessionId}`,
            '🛒 Đơn mua sắm mới đã hoàn tất!',
            'Bạn vừa hoàn thành một phiên mua sắm mới. Hãy kiểm tra và thêm các sản phẩm vừa mua vào tủ lạnh ngay nhé!',
          JSON.stringify({ sessionId, screen: 'shopping_session' })],
        );
      }
    }
    await audit(db, ctx, 'shopping.purchase', 'shopping_session', sessionId, { items: results.map((r) => r.itemId) });

    const response = { sessionId, results };
    await db.query('UPDATE idempotency_keys SET response = $3, status_code = 200 WHERE user_id = $1 AND key = $2', [
      ctx.userId,
      key,
      JSON.stringify(response),
    ]);
    return { response, replayed: false };
  });

  if (!out.replayed) triggerExpiryScan(groupId);
  return result('00510', { ...out.response, replayed: out.replayed, session: await getShoppingSessionById(groupId, sessionId) });
}

/** POST fridge/items/from-purchase - Nhập từng item đã mua vào tủ lạnh. */
export async function addPurchasedItemsToFridge(ctx, body = {}, idempotencyKey) {
  const key = typeof idempotencyKey === 'string' ? idempotencyKey.trim() : '';
  ensure(key.length >= 8 && key.length <= 100, '00511');
  const sessionId = toId(body.sessionId);
  ensure(sessionId, '00251');
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
  const requestHash = crypto.createHash('sha256').update(JSON.stringify({ sessionId, items })).digest('hex');
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
      `SELECT si.*, f.name AS food_name, un.name AS unit_name, ss.completed_at
       FROM shopping_items si
       JOIN shopping_sessions ss ON ss.id = si.session_id
       JOIN foods f ON f.id = si.food_id JOIN units un ON un.id = f.unit_id
       WHERE si.session_id = $1 AND si.group_id = $2 AND si.id = ANY($3::bigint[]) FOR UPDATE OF t`,
      [sessionId, groupId, items.map((item) => item.itemId)],
    );
    const byId = new Map(dbItems.map((item) => [si.id, item]));
    const results = [];
    for (const item of items) {
      const item = byId.get(si.itemId);
      ensure(item && item.status === 'bought', '00514', { itemId: si.itemId });
      const inserted = await db.query(
        `INSERT INTO fridge_items (
           group_id, food_id, shopping_item_id, batch_code, quantity, use_within, location, note, purchased_at
         )
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING id, quantity, use_within`,
        [groupId, item.food_id, item.id, `shopping-session:${sessionId}`, item.purchased_quantity ?? item.quantity,
          item.useWithin, item.location, item.note, item.purchased_at ?? item.completed_at],
      );
      await db.query(`UPDATE shopping_items SET status = 'in_fridge' WHERE id = $1`, [item.id]);
      await recordStockEvent(db, {
        groupId, food: item, type: 'add', quantity: item.purchased_quantity ?? item.quantity,
        actorUserId: ctx.userId, shoppingItemId: item.id, note: item.note,
      });
      results.push({
        itemId: item.id, fridgeItemId: inserted.rows[0].id, foodName: item.food_name,
        quantity: inserted.rows[0].quantity, useWithin: inserted.rows[0].use_within, unit: item.unit_name
      });
    }
    const response = { sessionId, results };
    await db.query('UPDATE idempotency_keys SET response = $3, status_code = 200 WHERE user_id = $1 AND key = $2',
      [ctx.userId, key, JSON.stringify(response)]);
    return { response, replayed: false };
  });
  if (!out.replayed) triggerExpiryScan(groupId);
  return result('00202', { ...out.response, replayed: out.replayed, session: await getShoppingSessionById(groupId, sessionId) });
}
