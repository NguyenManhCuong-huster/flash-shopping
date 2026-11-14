-- Chuẩn hóa thuật ngữ shopping task thành shopping item.
ALTER TABLE shopping_tasks RENAME TO shopping_items;
ALTER TABLE shopping_items RENAME CONSTRAINT shopping_tasks_list_food_uq TO shopping_items_list_food_uq;
ALTER TABLE shopping_items RENAME CONSTRAINT shopping_tasks_status_check TO shopping_items_status_check;

ALTER INDEX IF EXISTS shopping_tasks_status_idx RENAME TO shopping_items_status_idx;

ALTER TABLE fridge_items RENAME COLUMN shopping_task_id TO shopping_item_id;
ALTER TABLE stock_events RENAME COLUMN shopping_task_id TO shopping_item_id;

ALTER INDEX IF EXISTS fridge_items_shopping_task_uq RENAME TO fridge_items_shopping_item_uq;
ALTER INDEX IF EXISTS idx_fridge_items_task RENAME TO idx_fridge_items_item;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'fridge_items_shopping_task_id_fkey'
  ) THEN
    ALTER TABLE fridge_items
      RENAME CONSTRAINT fridge_items_shopping_task_id_fkey TO fridge_items_shopping_item_id_fkey;
  END IF;
END $$;
