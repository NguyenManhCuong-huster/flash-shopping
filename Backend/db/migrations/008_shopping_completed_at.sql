-- Thêm cột completed_at cho shopping_lists (thời điểm đơn mua hoàn tất)
ALTER TABLE shopping_lists
ADD COLUMN completed_at TIMESTAMPTZ;

-- Cho phép shopping_date NULL vì sẽ thay thế bằng createdAt/completedAt
ALTER TABLE shopping_lists ALTER COLUMN shopping_date DROP NOT NULL;

DROP INDEX IF EXISTS shopping_lists_group_date_idx;

-- Index hỗ trợ truy vấn danh sách đã hoàn thành
CREATE INDEX shopping_lists_completed_at_idx ON shopping_lists (completed_at) WHERE completed_at IS NOT NULL;