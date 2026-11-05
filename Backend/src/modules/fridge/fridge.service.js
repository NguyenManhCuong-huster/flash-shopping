import { env } from '../../config/env.js';
import { query, withTx } from '../../db/pool.js';
import { AppError, result } from '../../common/errors.js';
import {
  ensure, isoDate, isoDateTime, isPresent, LOCATIONS, optionalNote, pageMeta, parsePage, positiveNumber, toId,
} from '../../common/validate.js';
import { zonedDateTimeToUtc } from '../../common/time.js';
import { requireMember } from '../../common/permissions.js';
import { audit } from '../../common/audit.js';
import { findFoodByName } from '../food/food.repo.js';
import { recordStockEvent, round3 } from '../stock/stock.repo.js';
import { triggerExpiryScan } from '../notification/expiry.job.js';

export const FRIDGE_SELECT = `
  SELECT fi.id, fi.group_id, fi.quantity, fi.use_within, fi.location, fi.note, fi.version,
         fi.created_at, fi.updated_at,
         f.id AS food_id, f.name AS food_name, f.image_url AS food_image_url,
         c.id AS category_id, c.name AS category_name, un.id AS unit_id, un.name AS unit_name
    FROM fridge_items fi
    JOIN foods f ON f.id = fi.food_id
    JOIN categories c ON c.id = f.category_id
    JOIN units un ON un.id = f.unit_id`;

export function toFridgeDto(r) {
  if (!r) return null;
  const ms = new Date(r.use_within).getTime() - Date.now();
  const status = ms < 0 ? 'expired' : ms <= env.expiryReminderDays * 86400_000 ? 'expiring' : 'fresh';
  return {
    id: r.id,
    food: {
      id: r.food_id,
      name: r.food_name,
      imageUrl: r.food_image_url,
      category: { id: r.category_id, name: r.category_name },
      unit: { id: r.unit_id, name: r.unit_name },
    },
    quantity: r.quantity,
    useWithin: r.use_within,
    location: r.location,
    note: r.note,
    version: r.version,
    status,
    daysLeft: Math.floor(ms / 86400_000),
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

/**
 * Hạn sử dụng nhận 3 dạng (báo cáo: useWithin chưa rõ đơn vị):
 *  - ISO 8601 có múi giờ: "2026-11-10T18:00:00+07:00"
 *  - Ngày "YYYY-MM-DD": hết hạn cuối ngày đó theo múi giờ người dùng
 *  - Số ngày (1..3650): tính từ hiện tại
 */
export function parseUseWithin(v, tz) {
  if (v === undefined || v === null || v === '') return null;
  let d = null;
  const s = String(v).trim();
  if (/^\d{1,4}$/.test(s)) {
    const n = Number(s);
    if (n >= 1 && n <= 3650) d = new Date(Date.now() + n * 86400_000);
  } else if (isoDate(s)) {
    d = zonedDateTimeToUtc(s, 23, 59, 59, tz);
  } else {
    d = isoDateTime(s);
  }
  if (!d) return null;
  const y = d.getUTCFullYear();
  return y >= 2000 && y <= 2100 ? d : null;
}

const getItem = async (db, groupId, itemId, lock = false) =>
  (await db.query(`${FRIDGE_SELECT} WHERE fi.id = $1 AND fi.group_id = $2 ${lock ? 'FOR UPDATE OF fi' : ''}`, [itemId, groupId]))
    .rows[0];

const parseVersion = (v) => (v === undefined || v === null || v === '' ? null : toId(v));

/** GET fridge/?q&categoryId&location&expiringDays&sort&page&limit */
export async function listItems(ctx, q = {}) {
  const groupId = requireMember(ctx, '00225');
  const p = parsePage(q, { defaultLimit: 50 });
  const params = [groupId];
  const where = ['fi.group_id = $1'];
  const add = (sql, v) => {
    params.push(v);
    where.push(sql.replaceAll('?', `$${params.length}`));
  };
  if (isPresent(q.q)) add('f.name ILIKE ?', `%${String(q.q).trim()}%`);
  if (toId(q.categoryId)) add('f.category_id = ?', toId(q.categoryId));
  if (LOCATIONS.includes(q.location)) add('fi.location = ?', q.location);
  if (toId(q.expiringDays)) add(`fi.use_within <= now() + make_interval(days => ?::int)`, toId(q.expiringDays));
  const w = where.join(' AND ');
  const order = q.sort === 'name' ? 'f.name' : 'fi.use_within, f.name';
  const total = (await query(`SELECT count(*)::int AS n FROM fridge_items fi JOIN foods f ON f.id = fi.food_id WHERE ${w}`, params))
    .rows[0].n;
  const { rows } = await query(`${FRIDGE_SELECT} WHERE ${w} ORDER BY ${order} LIMIT ${p.limit} OFFSET ${p.offset}`, params);
  const summary = (
    await query(
      `SELECT count(*)::int AS total,
              count(*) FILTER (WHERE use_within < now())::int AS expired,
              count(*) FILTER (WHERE use_within >= now() AND use_within <= now() + make_interval(days => $2::int))::int AS expiring
         FROM fridge_items WHERE group_id = $1`,
      [groupId, env.expiryReminderDays],
    )
  ).rows[0];
  return result('00228', { items: rows.map(toFridgeDto), summary, ...pageMeta(p, total) });
}

/** GET fridge/:foodName/ */
export async function getByFoodName(ctx, foodName) {
  ensure(isPresent(foodName), '00229');
  const groupId = requireMember(ctx, '00232');
  const food = await findFoodByName(null, groupId, foodName);
  ensure(food, '00230');
  const { rows } = await query(`${FRIDGE_SELECT} WHERE fi.group_id = $1 AND fi.food_id = $2`, [groupId, food.id]);
  ensure(rows[0], '00234');
  return result('00237', { item: toFridgeDto(rows[0]) });
}

/** GET fridge/item/:itemId/ - Mở chi tiết từ thông báo nhắc hạn (UC06 bước 6). */
export async function getById(ctx, rawId) {
  const itemId = toId(rawId);
  ensure(itemId, '00204');
  const groupId = requireMember(ctx, '00232');
  const item = await getItem({ query }, groupId, itemId);
  ensure(item, '00234');
  return result('00237', { item: toFridgeDto(item) });
}

/** POST fridge/ - Ghi nhận thực phẩm vào tủ lạnh. */
export async function createItem(ctx, body = {}) {
  ensure(isPresent(body.foodName) || isPresent(body.useWithin) || isPresent(body.quantity), '00203');
  ensure(isPresent(body.foodName), '00190');
  const useWithin = parseUseWithin(body.useWithin, ctx.timezone);
  ensure(useWithin, '00191');
  const quantity = positiveNumber(body.quantity);
  ensure(quantity, '00192');
  const note = optionalNote(body.note);
  ensure(note.ok, '00193');
  const location = body.location ?? 'cool';
  ensure(LOCATIONS.includes(location), '00517');
  const groupId = requireMember(ctx, '00196');
  const food = await findFoodByName(null, groupId, body.foodName);
  ensure(food, '00194');

  let itemId;
  try {
    itemId = await withTx(async (db) => {
      const { rows } = await db.query(
        `INSERT INTO fridge_items (group_id, food_id, quantity, use_within, location, note)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
        [groupId, food.id, quantity, useWithin, location, note.value],
      );
      await recordStockEvent(db, { groupId, food, type: 'add', quantity, actorUserId: ctx.userId });
      await audit(db, ctx, 'fridge.create', 'fridge_item', rows[0].id, { food: food.name, quantity });
      return rows[0].id;
    });
  } catch (err) {
    // Mỗi nhóm một mục cho một thực phẩm: hướng người dùng sang cập nhật số lượng
    if (err.code === '23505') throw new AppError('00199');
    throw err;
  }
  triggerExpiryScan(groupId);
  return result('00202', { item: toFridgeDto(await getItem({ query }, groupId, itemId)) });
}

/** PUT fridge/ - Cập nhật số lượng/hạn/vị trí/ghi chú/thực phẩm. Gửi kèm `version` để chống ghi đè. */
export async function updateItem(ctx, body = {}) {
  const itemId = toId(body.itemId);
  ensure(itemId, '00204');
  const fields = ['newQuantity', 'newNote', 'newUseWithin', 'newFoodName', 'newLocation'];
  ensure(fields.some((f) => body[f] !== undefined && body[f] !== ''), '00204x');

  let newUseWithin = null;
  if (isPresent(body.newUseWithin)) {
    newUseWithin = parseUseWithin(body.newUseWithin, ctx.timezone);
    ensure(newUseWithin, '00205');
  }
  let newQuantity = null;
  if (isPresent(body.newQuantity)) {
    newQuantity = positiveNumber(body.newQuantity);
    ensure(newQuantity, '00206');
  }
  const newNote = body.newNote !== undefined ? optionalNote(body.newNote) : null;
  if (newNote) ensure(newNote.ok, '00207');
  if (isPresent(body.newLocation)) ensure(LOCATIONS.includes(body.newLocation), '00517');
  const version = parseVersion(body.version);
  const groupId = requireMember(ctx, '00210');

  try {
    await withTx(async (db) => {
      const item = await getItem(db, groupId, itemId, true);
      ensure(item, '00213');
      ensure(version === null || version === item.version, '00523', { currentVersion: item.version });

      const sets = ['version = version + 1', 'updated_at = now()'];
      const params = [itemId];
      const push = (col, v) => {
        params.push(v);
        sets.push(`${col} = $${params.length}`);
      };
      let food = item;
      if (isPresent(body.newFoodName)) {
        const nf = await findFoodByName(db, groupId, body.newFoodName);
        ensure(nf, '00214x');
        push('food_id', nf.id);
        food = { ...nf, food_id: nf.id, food_name: nf.name };
      }
      if (newQuantity !== null) push('quantity', newQuantity);
      if (newUseWithin) push('use_within', newUseWithin);
      if (newNote) push('note', newNote.value);
      if (isPresent(body.newLocation)) push('location', body.newLocation);
      await db.query(`UPDATE fridge_items SET ${sets.join(', ')} WHERE id = $1`, params);

      if (newQuantity !== null && newQuantity !== item.quantity) {
        await recordStockEvent(db, {
          groupId, food, type: 'adjust', quantity: round3(newQuantity - item.quantity), actorUserId: ctx.userId,
        });
      }
      await audit(db, ctx, 'fridge.update', 'fridge_item', itemId, {
        newQuantity, newUseWithin, newFoodName: body.newFoodName, newLocation: body.newLocation,
      });
    });
  } catch (err) {
    if (err.code === '23505') throw new AppError('00199');
    throw err;
  }
  if (newUseWithin) triggerExpiryScan(groupId);
  return result('00216', { item: toFridgeDto(await getItem({ query }, groupId, itemId)) });
}

/** DELETE fridge/ {foodName | itemId} */
export async function deleteItem(ctx, body = {}) {
  ensure(isPresent(body.foodName) || isPresent(body.itemId), '00217');
  const groupId = requireMember(ctx, '00219');
  await withTx(async (db) => {
    let item;
    if (isPresent(body.itemId)) {
      const id = toId(body.itemId);
      ensure(id, '00204');
      item = await getItem(db, groupId, id, true);
    } else {
      const food = await findFoodByName(db, groupId, body.foodName);
      ensure(food, '00218');
      item = (await db.query(`${FRIDGE_SELECT} WHERE fi.group_id = $1 AND fi.food_id = $2 FOR UPDATE OF fi`, [groupId, food.id]))
        .rows[0];
    }
    ensure(item, '00221');
    await db.query('DELETE FROM fridge_items WHERE id = $1', [item.id]);
    await recordStockEvent(db, { groupId, food: item, type: 'remove', quantity: item.quantity, actorUserId: ctx.userId });
    await audit(db, ctx, 'fridge.delete', 'fridge_item', item.id, { food: item.food_name });
  });
  return result('00224');
}

/**
 * POST fridge/consume/ - Ghi nhận tiêu thụ hoặc hủy bỏ (UC05).
 * Trong một giao dịch: khóa dòng, kiểm tra version + tồn, trừ tồn, ghi lịch sử. Tồn kho không bao giờ âm.
 * Hết tồn => xóa mục tủ lạnh (CHECK quantity > 0).
 */
export async function consumeItem(ctx, body = {}) {
  const itemId = toId(body.itemId);
  ensure(itemId, '00204');
  const type = body.type ?? 'consume';
  ensure(['consume', 'discard'].includes(type), '00524');
  const quantity = positiveNumber(body.quantity);
  ensure(quantity, '00521');
  const note = optionalNote(body.note);
  ensure(note.ok, '00193');
  const version = parseVersion(body.version);
  const groupId = requireMember(ctx, '00210');

  const out = await withTx(async (db) => {
    const item = await getItem(db, groupId, itemId, true);
    ensure(item, '00213');
    ensure(version === null || version === item.version, '00523', { currentVersion: item.version });
    ensure(quantity <= item.quantity + 1e-9, '00522', { available: item.quantity });
    const remaining = round3(item.quantity - quantity);
    if (remaining <= 0) {
      await db.query('DELETE FROM fridge_items WHERE id = $1', [itemId]);
    } else {
      await db.query('UPDATE fridge_items SET quantity = $2, version = version + 1, updated_at = now() WHERE id = $1', [
        itemId,
        remaining,
      ]);
    }
    await recordStockEvent(db, { groupId, food: item, type, quantity, actorUserId: ctx.userId, note: note.value });
    await audit(db, ctx, `fridge.${type}`, 'fridge_item', itemId, { food: item.food_name, quantity });
    return { remaining: Math.max(0, remaining), depleted: remaining <= 0 };
  });
  const item = out.depleted ? null : toFridgeDto(await getItem({ query }, groupId, itemId));
  return result('00520', { item, consumed: quantity, type, ...out });
}
