-- Tách xác nhận mua khỏi thao tác nhập từng mặt hàng vào tủ lạnh.
ALTER TABLE shopping_tasks
  DROP CONSTRAINT IF EXISTS shopping_tasks_status_check;

ALTER TABLE shopping_tasks
  ADD CONSTRAINT shopping_tasks_status_check
  CHECK (status IN ('pending', 'bought', 'in_fridge'));

CREATE UNIQUE INDEX IF NOT EXISTS fridge_items_shopping_task_uq
  ON fridge_items (shopping_task_id)
  WHERE shopping_task_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS shopping_tasks_status_idx
  ON shopping_tasks (list_id, status);
