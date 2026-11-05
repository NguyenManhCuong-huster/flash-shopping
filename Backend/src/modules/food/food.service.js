import { query, withTx } from '../../db/pool.js';
import { AppError, result } from '../../common/errors.js';
import { cleanString, ensure, isPresent, pageMeta, parsePage, toId } from '../../common/validate.js';
import { requireLeader, requireMember } from '../../common/permissions.js';
import { audit } from '../../common/audit.js';
import { removeByUrl, removeUploaded } from '../../middlewares/upload.js';
import { FOOD_SELECT, findFoodByName, toFoodDto } from './food.repo.js';

const findCatalog = async (table, name) =>
  (await query(`SELECT id, name FROM ${table} WHERE lower(btrim(name)) = lower(btrim($1))`, [String(name)])).rows[0];

/** GET food/?q&categoryId&page&limit - Danh sách thực phẩm của nhóm (tìm kiếm, lọc danh mục). */
export async function listFoods(ctx, q = {}) {
  const groupId = requireMember(ctx, '00185');
  const p = parsePage(q, { defaultLimit: 50 });
  const params = [groupId];
  const where = ['f.group_id = $1'];
  if (isPresent(q.q)) {
    params.push(`%${String(q.q).trim()}%`);
    where.push(`f.name ILIKE $${params.length}`);
  }
  if (toId(q.categoryId)) {
    params.push(toId(q.categoryId));
    where.push(`f.category_id = $${params.length}`);
  }
  const w = where.join(' AND ');
  const total = (await query(`SELECT count(*)::int AS n FROM foods f WHERE ${w}`, params)).rows[0].n;
  const { rows } = await query(`${FOOD_SELECT} WHERE ${w} ORDER BY f.name LIMIT ${p.limit} OFFSET ${p.offset}`, params);
  return result('00188', { foods: rows.map(toFoodDto), ...pageMeta(p, total) });
}

/** POST food/ (multipart) - Thành viên nhóm tạo thực phẩm. */
export async function createFood(ctx, body = {}, file = null, imageUrl = null) {
  try {
    ensure(isPresent(body.name) || isPresent(body.foodCategoryName) || isPresent(body.unitName), '00147');
    const name = cleanString(body.name, { min: 1, max: 150 });
    ensure(name, '00148');
    ensure(isPresent(body.foodCategoryName), '00149');
    ensure(isPresent(body.unitName), '00150');
    const groupId = requireMember(ctx, '00156x');
    const unit = await findCatalog('units', body.unitName);
    ensure(unit, '00153');
    const category = await findCatalog('categories', body.foodCategoryName);
    ensure(category, '00155');

    const id = await withTx(async (db) => {
      const { rows } = await db.query(
        `INSERT INTO foods (group_id, category_id, unit_id, name, image_url) VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [groupId, category.id, unit.id, name, imageUrl],
      );
      await audit(db, ctx, 'food.create', 'food', rows[0].id, { name });
      return rows[0].id;
    });
    const food = (await query(`${FOOD_SELECT} WHERE f.id = $1`, [id])).rows[0];
    return result('00160', { food: toFoodDto(food) });
  } catch (err) {
    removeUploaded(file);
    if (err.code === '23505') throw new AppError('00151');
    throw err;
  }
}

/** PUT food/ (multipart) - Trưởng nhóm sửa tên/danh mục/đơn vị/ảnh. */
export async function updateFood(ctx, body = {}, file = null, imageUrl = null) {
  try {
    ensure(isPresent(body.name), '00161');
    const name = cleanString(body.name, { min: 1, max: 150 });
    ensure(name, '00162');
    ensure(isPresent(body.newName) || isPresent(body.newCategory) || isPresent(body.newUnit) || file, '00163');
    let newName = null;
    if (isPresent(body.newName)) {
      newName = cleanString(body.newName, { min: 1, max: 150 });
      ensure(newName, '00166');
    }
    if (body.newCategory !== undefined && body.newCategory !== '') ensure(cleanString(body.newCategory, { max: 100 }), '00164');
    if (body.newUnit !== undefined && body.newUnit !== '') ensure(cleanString(body.newUnit, { max: 100 }), '00165');

    const groupId = requireMember(ctx, '00185');
    const food = await findFoodByName(null, groupId, name);
    ensure(food, '00167');
    if (ctx.groupRole !== 'admin') throw new AppError('00167x');

    const sets = [];
    const params = [food.id];
    const push = (col, v) => {
      params.push(v);
      sets.push(`${col} = $${params.length}`);
    };
    if (newName) push('name', newName);
    if (isPresent(body.newUnit)) {
      const unit = await findCatalog('units', body.newUnit);
      ensure(unit, '00169');
      push('unit_id', unit.id);
    }
    if (isPresent(body.newCategory)) {
      const category = await findCatalog('categories', body.newCategory);
      ensure(category, '00171');
      push('category_id', category.id);
    }
    if (file) push('image_url', imageUrl);

    await withTx(async (db) => {
      await db.query(`UPDATE foods SET ${sets.join(', ')} WHERE id = $1`, params);
      await audit(db, ctx, 'food.update', 'food', food.id, { name, newName, newUnit: body.newUnit, newCategory: body.newCategory });
    });
    if (file && food.image_url) removeByUrl(food.image_url);
    const updated = (await query(`${FOOD_SELECT} WHERE f.id = $1`, [food.id])).rows[0];
    return result('00178', { food: toFoodDto(updated) });
  } catch (err) {
    removeUploaded(file);
    if (err.code === '23505') throw new AppError('00173');
    throw err;
  }
}

/** DELETE food/ {name} - Trưởng nhóm xóa thực phẩm (xóa kèm mục tủ lạnh, nhiệm vụ, kế hoạch, công thức liên quan). */
export async function deleteFood(ctx, body = {}) {
  ensure(isPresent(body.name), '00179');
  const groupId = requireLeader(ctx, '00185', '00181');
  const food = await findFoodByName(null, groupId, body.name);
  ensure(food, '00180');
  await withTx(async (db) => {
    await db.query('DELETE FROM foods WHERE id = $1 AND group_id = $2', [food.id, groupId]);
    await audit(db, ctx, 'food.delete', 'food', food.id, { name: food.name });
  });
  removeByUrl(food.image_url);
  return result('00184');
}
