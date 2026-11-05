import { env } from '../../config/env.js';
import { round3 } from '../stock/stock.repo.js';

/**
 * Nguyên liệu cần của các công thức: recipes.food_id (nguyên liệu chính, không định lượng nếu
 * không khai báo lại trong recipe_ingredients) + các dòng recipe_ingredients.
 * Trả Map<recipeId, Array<{foodId, foodName, unitName, quantity|null}>>
 */
export async function loadRecipeRequirements(db, groupId, recipeIds) {
  const map = new Map(recipeIds.map((id) => [id, []]));
  if (!recipeIds.length) return map;
  const { rows } = await db.query(
    `SELECT r.id AS recipe_id, f.id AS food_id, f.name AS food_name, un.name AS unit_name, NULL::numeric AS quantity, 0 AS ord
       FROM recipes r JOIN foods f ON f.id = r.food_id JOIN units un ON un.id = f.unit_id
      WHERE r.group_id = $1 AND r.id = ANY($2::bigint[])
        AND NOT EXISTS (SELECT 1 FROM recipe_ingredients ri WHERE ri.recipe_id = r.id AND ri.food_id = r.food_id)
     UNION ALL
     SELECT ri.recipe_id, f.id, f.name, un.name, ri.quantity, 1
       FROM recipe_ingredients ri JOIN foods f ON f.id = ri.food_id JOIN units un ON un.id = f.unit_id
      WHERE ri.group_id = $1 AND ri.recipe_id = ANY($2::bigint[])
     ORDER BY 1, ord, food_name`,
    [groupId, recipeIds],
  );
  for (const r of rows) {
    map.get(r.recipe_id)?.push({ foodId: r.food_id, foodName: r.food_name, unitName: r.unit_name, quantity: r.quantity });
  }
  return map;
}

/** Tồn kho tủ lạnh theo thực phẩm: Map<foodId, {quantity, useWithin, expiring}> */
export async function loadFridgeStock(db, groupId) {
  const { rows } = await db.query(
    `SELECT food_id, quantity, use_within,
            (use_within <= now() + make_interval(days => $2::int)) AS expiring,
            (use_within < now()) AS expired
       FROM fridge_items WHERE group_id = $1`,
    [groupId, env.expiryReminderDays],
  );
  return new Map(rows.map((r) => [r.food_id, { quantity: r.quantity, useWithin: r.use_within, expiring: r.expiring, expired: r.expired }]));
}

/**
 * So sánh nhu cầu với tồn kho. quantity = null nghĩa là "cần có" (không định lượng):
 * đủ khi tủ còn > 0, thiếu thì đề xuất mua 1 đơn vị.
 * Thực phẩm đã quá hạn không được tính là "đang có".
 */
export function compareWithStock(requirements, stock) {
  return requirements.map((req) => {
    const s = stock.get(req.foodId);
    const available = s && !s.expired ? s.quantity : 0;
    let missing;
    if (req.quantity == null) missing = available > 0 ? 0 : 1;
    else missing = Math.max(0, round3(req.quantity - available));
    return {
      food: { id: req.foodId, name: req.foodName, unit: req.unitName },
      requiredQuantity: req.quantity,
      availableQuantity: available,
      missingQuantity: missing,
      enough: missing === 0,
      expiringSoon: !!(s && s.expiring && !s.expired),
    };
  });
}

/** Gộp nhu cầu của nhiều món (vd. mọi bữa trong ngày) theo thực phẩm. */
export function mergeRequirements(lists) {
  const byFood = new Map();
  for (const list of lists) {
    for (const r of list) {
      const cur = byFood.get(r.foodId);
      if (!cur) byFood.set(r.foodId, { ...r });
      else if (cur.quantity == null) cur.quantity = r.quantity;
      else if (r.quantity != null) cur.quantity = round3(cur.quantity + r.quantity);
    }
  }
  return [...byFood.values()];
}
