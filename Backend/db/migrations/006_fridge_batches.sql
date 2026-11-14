-- Cho phép tủ lạnh có nhiều đợt mua cho cùng một thực phẩm (khác hạn sử dụng, khác đợt mua)
-- Bỏ ràng buộc UNIQUE(group_id, food_id) cũ
ALTER TABLE fridge_items DROP CONSTRAINT IF EXISTS fridge_items_group_food_uq;

-- Thêm cột tham chiếu đến nhiệm vụ mua sắm (để biết món này thuộc đợt mua nào)
ALTER TABLE fridge_items
ADD COLUMN IF NOT EXISTS shopping_task_id BIGINT REFERENCES shopping_tasks (id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS batch_code VARCHAR(50);

-- Index để tra cứu nhanh các đợt của cùng một thực phẩm trong nhóm
CREATE INDEX IF NOT EXISTS idx_fridge_items_group_food ON fridge_items (group_id, food_id);
CREATE INDEX IF NOT EXISTS idx_fridge_items_task ON fridge_items (shopping_task_id) WHERE shopping_task_id IS NOT NULL;

-- Mã liên kết giữa phiên mua sắm và các mục tủ lạnh (dùng cho thông báo "đơn mua mới hoàn tất")
CREATE INDEX IF NOT EXISTS idx_fridge_items_batch ON fridge_items (batch_code) WHERE batch_code IS NOT NULL;