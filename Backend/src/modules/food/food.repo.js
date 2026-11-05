import { query } from '../../db/pool.js';

export const FOOD_SELECT = `
  SELECT f.id, f.group_id, f.name, f.image_url, f.created_at,
         c.id AS category_id, c.name AS category_name,
         un.id AS unit_id, un.name AS unit_name
    FROM foods f
    JOIN categories c ON c.id = f.category_id
    JOIN units un ON un.id = f.unit_id`;

export const toFoodDto = (r) =>
  r && {
    id: r.id,
    name: r.name,
    imageUrl: r.image_url,
    category: { id: r.category_id, name: r.category_name },
    unit: { id: r.unit_id, name: r.unit_name },
    createdAt: r.created_at,
  };

/** Tìm thực phẩm theo tên trong phạm vi nhóm (không phân biệt hoa thường). */
export async function findFoodByName(db, groupId, name) {
  const { rows } = await (db ?? { query }).query(
    `${FOOD_SELECT} WHERE f.group_id = $1 AND lower(btrim(f.name)) = lower(btrim($2))`,
    [groupId, String(name ?? '').normalize('NFC')],
  );
  return rows[0] ?? null;
}

export async function findFoodById(db, groupId, id) {
  const { rows } = await (db ?? { query }).query(`${FOOD_SELECT} WHERE f.group_id = $1 AND f.id = $2`, [groupId, id]);
  return rows[0] ?? null;
}
