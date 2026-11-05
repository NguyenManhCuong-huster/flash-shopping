import { query, withTx } from '../../db/pool.js';
import { result } from '../../common/errors.js';
import {
  cleanString, ensure, isoDate, isoDateTime, isPresent, maybeJson, mealName, toId,
} from '../../common/validate.js';
import { addDays, daysBetween, localDate, zonedDateTimeToUtc } from '../../common/time.js';
import { requireLeader, requireMember } from '../../common/permissions.js';
import { audit } from '../../common/audit.js';
import { findFoodByName } from '../food/food.repo.js';
import { compareWithStock, loadFridgeStock, loadRecipeRequirements, mergeRequirements } from '../recipe/ingredients.js';
import { loadList } from '../shopping/shopping.service.js';

const DEFAULT_TIME = { 'sáng': [7, 0], 'trưa': [11, 30], 'tối': [18, 30] };

const PLAN_SELECT = `
  SELECT mp.id, mp.group_id, mp.planned_at, mp.meal_name, mp.recipe_id, mp.created_at, mp.created_by,
         f.id AS food_id, f.name AS food_name, f.image_url AS food_image_url, un.name AS unit_name,
         r.name AS recipe_name
    FROM meal_plans mp
    JOIN foods f ON f.id = mp.food_id
    JOIN units un ON un.id = f.unit_id
    LEFT JOIN recipes r ON r.id = mp.recipe_id`;

const toPlanDto = (p, tz) => ({
  id: p.id,
  date: localDate(new Date(p.planned_at), tz),
  plannedAt: p.planned_at,
  mealName: p.meal_name,
  food: { id: p.food_id, name: p.food_name, imageUrl: p.food_image_url, unit: p.unit_name },
  recipe: p.recipe_id ? { id: p.recipe_id, name: p.recipe_name } : null,
  createdBy: p.created_by,
  createdAt: p.created_at,
});

/** timestamp: ISO có múi giờ, hoặc 'YYYY-MM-DD' => giờ mặc định của bữa theo múi giờ người dùng. */
function parsePlannedAt(v, meal, tz) {
  const d = isoDateTime(v);
  if (d) return d;
  const day = isoDate(v);
  if (!day) return null;
  const [h, m] = DEFAULT_TIME[meal] ?? [12, 0];
  return zonedDateTimeToUtc(day, h, m, 0, tz);
}

async function findRecipe(db, groupId, id) {
  return (await db.query('SELECT id, food_id FROM recipes WHERE id = $1 AND group_id = $2', [id, groupId])).rows[0] ?? null;
}

const getPlan = async (groupId, id, tz) => {
  const r = (await query(`${PLAN_SELECT} WHERE mp.id = $1 AND mp.group_id = $2`, [id, groupId])).rows[0];
  return r ? toPlanDto(r, tz) : null;
};

/** POST meal/ {foodName, timestamp, name, recipeId?} - Trưởng nhóm lập kế hoạch. */
export async function createPlan(ctx, body = {}) {
  ensure(['foodName', 'timestamp', 'name', 'recipeId'].some((k) => isPresent(body[k])), '00313');
  const hasRecipe = isPresent(body.recipeId);
  if (!hasRecipe || isPresent(body.foodName)) ensure(cleanString(body.foodName, { max: 150 }), '00314');
  const meal = mealName(body.name);
  ensure(meal, '00316');
  const plannedAt = parsePlannedAt(body.timestamp, meal, ctx.timezone);
  ensure(plannedAt, '00315');
  const recipeId = hasRecipe ? toId(body.recipeId) : null;
  if (hasRecipe) ensure(recipeId, '00538');
  const groupId = requireLeader(ctx, '00345', '00319');

  const id = await withTx(async (db) => {
    let foodId = null;
    if (recipeId) {
      const recipe = await findRecipe(db, groupId, recipeId);
      ensure(recipe, '00538');
      foodId = recipe.food_id;
    }
    if (isPresent(body.foodName)) {
      const food = await findFoodByName(db, groupId, body.foodName);
      ensure(food, '00317');
      foodId = food.id;
    }
    const { rows } = await db.query(
      `INSERT INTO meal_plans (group_id, food_id, recipe_id, planned_at, meal_name, created_by)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
      [groupId, foodId, recipeId, plannedAt, meal, ctx.userId],
    );
    await audit(db, ctx, 'meal.create', 'meal_plan', rows[0].id, { meal, plannedAt });
    return rows[0].id;
  });
  return result('00322', { plan: await getPlan(groupId, id, ctx.timezone) });
}

/** PUT meal/ {planId, newFoodName?, newTimestamp?, newName?, newRecipeId?} */
export async function updatePlan(ctx, body = {}) {
  ensure(body && Object.keys(body).length, '00331');
  const planId = toId(body.planId);
  ensure(planId, '00332');
  ensure(['newFoodName', 'newTimestamp', 'newName', 'newRecipeId'].some((k) => body[k] !== undefined), '00333');
  if (body.newFoodName !== undefined) ensure(cleanString(body.newFoodName, { max: 150 }), '00334');
  let newMeal = null;
  if (body.newName !== undefined) {
    newMeal = mealName(body.newName);
    ensure(newMeal, '00336');
  }
  const groupId = requireLeader(ctx, '00345', '00339');

  await withTx(async (db) => {
    const plan = (await db.query('SELECT * FROM meal_plans WHERE id = $1 AND group_id = $2 FOR UPDATE', [planId, groupId])).rows[0];
    ensure(plan, '00337');
    const sets = [];
    const params = [planId];
    const push = (col, v) => {
      params.push(v);
      sets.push(`${col} = $${params.length}`);
    };
    const meal = newMeal ?? plan.meal_name;
    if (newMeal) push('meal_name', newMeal);
    if (body.newTimestamp !== undefined) {
      const at = parsePlannedAt(body.newTimestamp, meal, ctx.timezone);
      ensure(at, '00335');
      push('planned_at', at);
    }
    if (body.newRecipeId !== undefined) {
      if (body.newRecipeId === null || body.newRecipeId === '') push('recipe_id', null);
      else {
        const rid = toId(body.newRecipeId);
        ensure(rid, '00538');
        const recipe = await findRecipe(db, groupId, rid);
        ensure(recipe, '00538');
        push('recipe_id', rid);
        if (body.newFoodName === undefined) push('food_id', recipe.food_id);
      }
    }
    if (body.newFoodName !== undefined) {
      const food = await findFoodByName(db, groupId, body.newFoodName);
      ensure(food, '00341');
      push('food_id', food.id);
    }
    await db.query(`UPDATE meal_plans SET ${sets.join(', ')} WHERE id = $1`, params);
    await audit(db, ctx, 'meal.update', 'meal_plan', planId, { newName: newMeal, newFoodName: body.newFoodName });
  });
  return result('00344', { plan: await getPlan(groupId, planId, ctx.timezone) });
}

/** DELETE meal/ {planId} */
export async function deletePlan(ctx, body = {}) {
  ensure(body && Object.keys(body).length, '00323');
  const planId = toId(body.planId);
  ensure(planId, '00324');
  const groupId = requireLeader(ctx, '00345', '00327');
  await withTx(async (db) => {
    const del = await db.query('DELETE FROM meal_plans WHERE id = $1 AND group_id = $2', [planId, groupId]);
    ensure(del.rowCount, '00325');
    await audit(db, ctx, 'meal.delete', 'meal_plan', planId);
  });
  return result('00330');
}

/** Khoảng ngày truy vấn: ?date hoặc ?from&to (tối đa 31 ngày), theo múi giờ người dùng. */
function resolveRange(q, tz) {
  if (isPresent(q.from) || isPresent(q.to)) {
    const from = isoDate(q.from);
    const to = isoDate(q.to);
    ensure(from && to && daysBetween(from, to) >= 0 && daysBetween(from, to) <= 31, '00315');
    return [from, to];
  }
  const date = isPresent(q.date) ? isoDate(q.date) : localDate(new Date(), tz);
  ensure(date, '00315');
  return [date, date];
}

async function plansInRange(groupId, from, to, tz) {
  const start = zonedDateTimeToUtc(from, 0, 0, 0, tz);
  const end = zonedDateTimeToUtc(addDays(to, 1), 0, 0, 0, tz);
  const { rows } = await query(
    `${PLAN_SELECT} WHERE mp.group_id = $1 AND mp.planned_at >= $2 AND mp.planned_at < $3
      ORDER BY mp.planned_at, CASE mp.meal_name WHEN 'sáng' THEN 1 WHEN 'trưa' THEN 2 ELSE 3 END, mp.id`,
    [groupId, start, end],
  );
  return rows;
}

/** GET meal/?date=YYYY-MM-DD hoặc ?from&to - Thành viên xem lịch ngày/tuần. */
export async function listPlans(ctx, q = {}) {
  const groupId = requireMember(ctx, '00345');
  const [from, to] = resolveRange(q, ctx.timezone);
  const rows = await plansInRange(groupId, from, to, ctx.timezone);
  return result('00348', { from, to, plans: rows.map((r) => toPlanDto(r, ctx.timezone)) });
}

/** Nhu cầu nguyên liệu của các kế hoạch: theo công thức nếu có, ngược lại là chính thực phẩm của bữa. */
async function analyse(groupId, planRows) {
  const db = { query };
  const recipeIds = [...new Set(planRows.filter((p) => p.recipe_id).map((p) => p.recipe_id))];
  const byRecipe = await loadRecipeRequirements(db, groupId, recipeIds);
  const lists = planRows.map((p) =>
    p.recipe_id
      ? byRecipe.get(p.recipe_id) ?? []
      : [{ foodId: p.food_id, foodName: p.food_name, unitName: p.unit_name, quantity: null }],
  );
  const stock = await loadFridgeStock(db, groupId);
  const ingredients = compareWithStock(mergeRequirements(lists), stock);
  return { ingredients, missing: ingredients.filter((i) => !i.enough) };
}

async function selectPlans(ctx, groupId, src) {
  const ids = maybeJson(src.planIds ?? (src.planId !== undefined ? `[${src.planId}]` : undefined));
  if (Array.isArray(ids)) {
    const planIds = ids.map(toId);
    ensure(planIds.length && planIds.every(Boolean), '00324');
    const { rows } = await query(`${PLAN_SELECT} WHERE mp.group_id = $1 AND mp.id = ANY($2::bigint[])`, [groupId, planIds]);
    ensure(rows.length === planIds.length, '00325');
    return rows;
  }
  const [from, to] = resolveRange(src, ctx.timezone);
  return plansInRange(groupId, from, to, ctx.timezone);
}

/** GET meal/ingredients/?planId | ?date | ?from&to - Nguyên liệu cần, đang có và còn thiếu (UC08 bước 3). */
export async function checkIngredients(ctx, q = {}) {
  const groupId = requireMember(ctx, '00345');
  const plans = await selectPlans(ctx, groupId, q);
  const { ingredients, missing } = await analyse(groupId, plans);
  return result('00535', { plans: plans.map((p) => toPlanDto(p, ctx.timezone)), ingredients, missing });
}

/**
 * POST meal/missing-to-shopping/ - Thao tác tùy chọn riêng (extend), không tự chạy khi lưu kế hoạch.
 * body: {planIds? | planId? | date? | from&to?, listId? | newListName?, newListDate?, assignToUsername?}
 */
export async function addMissingToShopping(ctx, body = {}) {
  const groupId = requireLeader(ctx, '00345', '00319');
  const plans = await selectPlans(ctx, groupId, body);
  const { missing } = await analyse(groupId, plans);
  if (!missing.length) return result('00537', { added: [], updated: [] });

  const listId = await withTx(async (db) => {
    let id;
    if (isPresent(body.listId)) {
      id = toId(body.listId);
      ensure(id, '00277');
      const l = await db.query('SELECT id FROM shopping_lists WHERE id = $1 AND group_id = $2 FOR UPDATE', [id, groupId]);
      ensure(l.rowCount, '00283');
    } else {
      const firstDate = plans.length ? localDate(new Date(plans[0].planned_at), ctx.timezone) : localDate(new Date(), ctx.timezone);
      const date = isPresent(body.newListDate) ? isoDate(body.newListDate) : firstDate;
      ensure(date, '00242');
      const name = isPresent(body.newListName)
        ? cleanString(body.newListName, { min: 1, max: 150 })
        : `Nguyên liệu bữa ăn ${date.split('-').reverse().join('/')}`;
      ensure(name, '00239');
      let assignee = null;
      if (isPresent(body.assignToUsername)) {
        const u = (await db.query('SELECT id FROM users WHERE username = $1', [String(body.assignToUsername).trim()])).rows[0];
        ensure(u, '00245');
        const m = await db.query('SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2', [groupId, u.id]);
        ensure(m.rowCount, '00246');
        assignee = u.id;
      }
      const ins = await db.query(
        `INSERT INTO shopping_lists (group_id, assigned_user_id, name, note, shopping_date, created_by)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
        [groupId, assignee, name, 'Tạo từ kế hoạch bữa ăn', date, ctx.userId],
      );
      id = ins.rows[0].id;
    }
    for (const m of missing) {
      // Đã có nhiệm vụ chưa mua cho thực phẩm này => cộng thêm phần thiếu
      await db.query(
        `INSERT INTO shopping_tasks (list_id, group_id, food_id, quantity) VALUES ($1, $2, $3, $4)
         ON CONFLICT (list_id, food_id) DO UPDATE SET quantity = shopping_tasks.quantity + EXCLUDED.quantity
         WHERE shopping_tasks.status = 'pending'`,
        [id, groupId, m.food.id, m.missingQuantity],
      );
    }
    await db.query('UPDATE shopping_lists SET updated_at = now() WHERE id = $1', [id]);
    await audit(db, ctx, 'meal.missing_to_shopping', 'shopping_list', id, { foods: missing.map((m) => m.food.name) });
    return id;
  });
  return result('00536', { listId, missing, list: await loadList(groupId, listId) });
}
