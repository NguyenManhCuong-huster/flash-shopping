/**
 * Ghi lịch sử biến động kho (stock_events). Luôn gọi bằng client của giao dịch đang chạy
 * để lịch sử và tồn kho cùng commit hoặc cùng rollback (NFR09).
 *
 * food: bản ghi có food_id|id, food_name|name, unit_name, category_name
 */
export async function recordStockEvent(db, { groupId, food, type, quantity, actorUserId, shoppingTaskId = null, note = null }) {
  await db.query(
    `INSERT INTO stock_events (group_id, food_id, food_name, unit_name, category_name, type, quantity,
                               actor_user_id, shopping_task_id, note)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
    [
      groupId,
      food.food_id ?? food.id,
      food.food_name ?? food.name,
      food.unit_name,
      food.category_name,
      type,
      quantity,
      actorUserId ?? null,
      shoppingTaskId,
      note,
    ],
  );
}

export const round3 = (n) => Math.round(n * 1000) / 1000;
