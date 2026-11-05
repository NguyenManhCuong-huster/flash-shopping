import sanitizeHtml from 'sanitize-html';
import { query, withTx } from '../../db/pool.js';
import { AppError, result } from '../../common/errors.js';
import { cleanString, ensure, isPresent, maybeJson, pageMeta, parsePage, positiveNumber, toId } from '../../common/validate.js';
import { requireMember } from '../../common/permissions.js';
import { audit } from '../../common/audit.js';
import { findFoodByName } from '../food/food.repo.js';
import { compareWithStock, loadFridgeStock, loadRecipeRequirements } from './ingredients.js';

const RECIPE_SELECT = `
  SELECT r.id, r.group_id, r.name, r.description, r.html_content, r.created_at, r.updated_at, r.created_by,
         cu.name AS created_by_name,
         f.id AS food_id, f.name AS food_name, f.image_url AS food_image_url, un.name AS unit_name
    FROM recipes r
    JOIN foods f ON f.id = r.food_id
    JOIN units un ON un.id = f.unit_id
    LEFT JOIN users cu ON cu.id = r.created_by`;

/** HTML công thức luôn được làm sạch trước khi lưu (chống XSS / chèn chỉ dẫn). */
export const cleanHtml = (html) =>
  sanitizeHtml(String(html), {
    allowedTags: ['p', 'br', 'b', 'strong', 'i', 'em', 'u', 'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'h4', 'blockquote', 'a', 'span'],
    allowedAttributes: { a: ['href'] },
    allowedSchemes: ['http', 'https'],
  }).trim();

function toRecipeDto(r, ingredients = null, { withHtml = true } = {}) {
  return {
    id: r.id,
    name: r.name,
    description: r.description,
    ...(withHtml ? { htmlContent: r.html_content } : {}),
    food: { id: r.food_id, name: r.food_name, imageUrl: r.food_image_url, unit: r.unit_name },
    createdBy: r.created_by ? { id: r.created_by, name: r.created_by_name } : null,
    ingredients,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

async function loadIngredients(db, recipeIds) {
  const map = new Map(recipeIds.map((id) => [id, []]));
  if (!recipeIds.length) return map;
  const { rows } = await db.query(
    `SELECT ri.recipe_id, ri.quantity, f.id AS food_id, f.name AS food_name, un.name AS unit_name
       FROM recipe_ingredients ri JOIN foods f ON f.id = ri.food_id JOIN units un ON un.id = f.unit_id
      WHERE ri.recipe_id = ANY($1::bigint[]) ORDER BY f.name`,
    [recipeIds],
  );
  for (const r of rows) {
    map.get(r.recipe_id).push({ food: { id: r.food_id, name: r.food_name, unit: r.unit_name }, quantity: r.quantity });
  }
  return map;
}

async function loadRecipe(db, groupId, id) {
  const r = (await db.query(`${RECIPE_SELECT} WHERE r.id = $1 AND r.group_id = $2`, [id, groupId])).rows[0];
  if (!r) return null;
  return toRecipeDto(r, (await loadIngredients(db, [id])).get(id));
}

/** ingredients: [{foodName, quantity?}] -> [{foodId, quantity|null}] (thực phẩm phải thuộc nhóm) */
async function resolveIngredients(db, groupId, raw) {
  const list = maybeJson(raw);
  ensure(Array.isArray(list) && list.length <= 50, '00532');
  const out = [];
  const seen = new Set();
  for (const [index, it] of list.entries()) {
    const name = typeof it?.foodName === 'string' ? it.foodName.trim() : '';
    ensure(name, '00532', { index, reason: 'Thiếu foodName' });
    let quantity = null;
    if (it.quantity !== undefined && it.quantity !== null && it.quantity !== '') {
      quantity = positiveNumber(it.quantity);
      ensure(quantity, '00532', { index, foodName: name, reason: 'Số lượng không hợp lệ' });
    }
    const food = await findFoodByName(db, groupId, name);
    ensure(food, '00532', { index, foodName: name, reason: 'Thực phẩm không tồn tại trong nhóm' });
    ensure(!seen.has(food.id), '00532', { index, foodName: name, reason: 'Nguyên liệu bị trùng' });
    seen.add(food.id);
    out.push({ foodId: food.id, quantity });
  }
  return out;
}

async function saveIngredients(db, groupId, recipeId, ingredients) {
  await db.query('DELETE FROM recipe_ingredients WHERE recipe_id = $1', [recipeId]);
  for (const ing of ingredients) {
    await db.query('INSERT INTO recipe_ingredients (recipe_id, group_id, food_id, quantity) VALUES ($1, $2, $3, $4)', [
      recipeId,
      groupId,
      ing.foodId,
      ing.quantity,
    ]);
  }
}

/** POST recipe/ {foodName, name, description, htmlContent, ingredients?} */
export async function createRecipe(ctx, body = {}) {
  ensure(['foodName', 'name', 'description', 'htmlContent'].some((k) => isPresent(body[k])), '00349');
  ensure(cleanString(body.foodName, { max: 150 }), '00350');
  const name = cleanString(body.name, { min: 1, max: 150 });
  ensure(name, '00351');
  const description = cleanString(body.description, { min: 1, max: 2000 });
  ensure(description, '00352');
  const html = typeof body.htmlContent === 'string' && body.htmlContent.length <= 50_000 ? cleanHtml(body.htmlContent) : '';
  ensure(html, '00353');
  const groupId = requireMember(ctx, '00185');
  const food = await findFoodByName(null, groupId, body.foodName);
  ensure(food, '00354');

  const id = await withTx(async (db) => {
    const ingredients = body.ingredients !== undefined ? await resolveIngredients(db, groupId, body.ingredients) : [];
    const { rows } = await db.query(
      `INSERT INTO recipes (group_id, food_id, created_by, name, description, html_content)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
      [groupId, food.id, ctx.userId, name, description, html],
    );
    await saveIngredients(db, groupId, rows[0].id, ingredients);
    await audit(db, ctx, 'recipe.create', 'recipe', rows[0].id, { name, food: food.name });
    return rows[0].id;
  });
  return result('00357', { recipe: await loadRecipe({ query }, groupId, id) });
}

/** Người tạo hoặc trưởng nhóm mới được sửa/xóa (created_by là bổ sung thiết kế của báo cáo). */
function assertCanModify(ctx, recipe) {
  if (recipe.created_by !== ctx.userId && ctx.groupRole !== 'admin') throw new AppError('00533');
}

/** PUT recipe/ {recipeId, newName?, newDescription?, newHtmlContent?, newFoodName?, newIngredients?} */
export async function updateRecipe(ctx, body = {}) {
  ensure(body && Object.keys(body).length, '00358');
  const recipeId = toId(body.recipeId);
  ensure(recipeId, '00359');
  const keys = ['newFoodName', 'newDescription', 'newHtmlContent', 'newName', 'newIngredients'];
  ensure(keys.some((k) => body[k] !== undefined), '00360');
  if (body.newFoodName !== undefined) ensure(cleanString(body.newFoodName, { max: 150 }), '00361');
  let newDescription = null;
  if (body.newDescription !== undefined) {
    newDescription = cleanString(body.newDescription, { min: 1, max: 2000 });
    ensure(newDescription, '00362');
  }
  let newHtml = null;
  if (body.newHtmlContent !== undefined) {
    newHtml = typeof body.newHtmlContent === 'string' && body.newHtmlContent.length <= 50_000 ? cleanHtml(body.newHtmlContent) : '';
    ensure(newHtml, '00363');
  }
  let newName = null;
  if (body.newName !== undefined) {
    newName = cleanString(body.newName, { min: 1, max: 150 });
    ensure(newName, '00364');
  }
  const groupId = requireMember(ctx, '00185');

  await withTx(async (db) => {
    const recipe = (await db.query('SELECT * FROM recipes WHERE id = $1 AND group_id = $2 FOR UPDATE', [recipeId, groupId])).rows[0];
    ensure(recipe, '00365');
    assertCanModify(ctx, recipe);
    const sets = ['updated_at = now()'];
    const params = [recipeId];
    const push = (col, v) => {
      params.push(v);
      sets.push(`${col} = $${params.length}`);
    };
    if (body.newFoodName !== undefined) {
      const food = await findFoodByName(db, groupId, body.newFoodName);
      ensure(food, '00367');
      push('food_id', food.id);
    }
    if (newName) push('name', newName);
    if (newDescription) push('description', newDescription);
    if (newHtml) push('html_content', newHtml);
    await db.query(`UPDATE recipes SET ${sets.join(', ')} WHERE id = $1`, params);
    if (body.newIngredients !== undefined) {
      await saveIngredients(db, groupId, recipeId, await resolveIngredients(db, groupId, body.newIngredients));
    }
    await audit(db, ctx, 'recipe.update', 'recipe', recipeId, { newName, newFoodName: body.newFoodName });
  });
  return result('00370', { recipe: await loadRecipe({ query }, groupId, recipeId) });
}

/** DELETE recipe/ {recipeId} */
export async function deleteRecipe(ctx, body = {}) {
  ensure(body && Object.keys(body).length, '00371');
  const recipeId = toId(body.recipeId);
  ensure(recipeId, '00372');
  const groupId = requireMember(ctx, '00185');
  await withTx(async (db) => {
    const recipe = (await db.query('SELECT * FROM recipes WHERE id = $1 AND group_id = $2 FOR UPDATE', [recipeId, groupId])).rows[0];
    ensure(recipe, '00373');
    assertCanModify(ctx, recipe);
    await db.query('DELETE FROM recipes WHERE id = $1', [recipeId]);
    await audit(db, ctx, 'recipe.delete', 'recipe', recipeId, { name: recipe.name });
  });
  return result('00376');
}

/** GET recipe/?foodId&q&page&limit - Tìm kiếm công thức (theo thực phẩm chính hoặc từ khóa). */
export async function listRecipes(ctx, q = {}) {
  const groupId = requireMember(ctx, '00185');
  const p = parsePage(q, { defaultLimit: 20 });
  const params = [groupId];
  const where = ['r.group_id = $1'];
  if (q.foodId !== undefined) {
    const foodId = toId(q.foodId);
    ensure(foodId, '00023');
    params.push(foodId);
    where.push(`(r.food_id = $${params.length} OR EXISTS (SELECT 1 FROM recipe_ingredients ri WHERE ri.recipe_id = r.id AND ri.food_id = $${params.length}))`);
  }
  if (isPresent(q.q)) {
    params.push(`%${String(q.q).trim()}%`);
    where.push(`(r.name ILIKE $${params.length} OR r.description ILIKE $${params.length} OR f.name ILIKE $${params.length})`);
  }
  const w = where.join(' AND ');
  const total = (await query(`SELECT count(*)::int AS n FROM recipes r JOIN foods f ON f.id = r.food_id WHERE ${w}`, params)).rows[0].n;
  const { rows } = await query(`${RECIPE_SELECT} WHERE ${w} ORDER BY r.updated_at DESC LIMIT ${p.limit} OFFSET ${p.offset}`, params);
  const ings = await loadIngredients({ query }, rows.map((r) => r.id));
  return result('00378', {
    recipes: rows.map((r) => toRecipeDto(r, ings.get(r.id), { withHtml: false })),
    ...pageMeta(p, total),
  });
}

/** GET recipe/:recipeId/ */
export async function getRecipe(ctx, rawId) {
  const id = toId(rawId);
  ensure(id, '00372');
  const groupId = requireMember(ctx, '00185');
  const recipe = await loadRecipe({ query }, groupId, id);
  ensure(recipe, '00373');
  return result('00378', { recipe });
}

/**
 * GET recipe/suggest/?onlyCookable=true&limit=20 - Gợi ý món từ tủ lạnh (UC09).
 * Ưu tiên: nấu được ngay > dùng nhiều nguyên liệu sắp hết hạn > tỉ lệ nguyên liệu sẵn có.
 */
export async function suggestRecipes(ctx, q = {}) {
  const groupId = requireMember(ctx, '00185');
  const limit = Math.min(50, Math.max(1, Number.parseInt(q.limit, 10) || 20));
  const db = { query };
  const { rows } = await query(`${RECIPE_SELECT} WHERE r.group_id = $1`, [groupId]);
  const reqs = await loadRecipeRequirements(db, groupId, rows.map((r) => r.id));
  const stock = await loadFridgeStock(db, groupId);

  let suggestions = rows.map((r) => {
    const ingredients = compareWithStock(reqs.get(r.id) ?? [], stock);
    const available = ingredients.filter((i) => i.enough).length;
    const expiring = ingredients.filter((i) => i.enough && i.expiringSoon).map((i) => i.food.name);
    return {
      recipe: toRecipeDto(r, null, { withHtml: false }),
      totalIngredients: ingredients.length,
      availableIngredients: available,
      canCook: ingredients.length > 0 && available === ingredients.length,
      expiringIngredients: expiring,
      missing: ingredients.filter((i) => !i.enough),
      ingredients,
    };
  });
  if (q.onlyCookable === 'true') suggestions = suggestions.filter((s) => s.canCook);
  suggestions.sort(
    (a, b) =>
      Number(b.canCook) - Number(a.canCook) ||
      b.expiringIngredients.length - a.expiringIngredients.length ||
      b.availableIngredients / (b.totalIngredients || 1) - a.availableIngredients / (a.totalIngredients || 1),
  );
  return result('00530', { suggestions: suggestions.slice(0, limit) });
}
