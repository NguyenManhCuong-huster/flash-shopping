-- Thêm cột completed_at cho shopping_sessions (thời điểm đơn mua hoàn tất)
ALTER TABLE shopping_sessions
ADD COLUMN completed_at TIMESTAMPTZ;

-- Cho phép shopping_date NULL vì sẽ thay thế bằng createdAt/completedAt
ALTER TABLE shopping_sessions ALTER COLUMN shopping_date DROP NOT NULL;

DROP INDEX IF EXISTS shopping_sessions_group_date_idx;

-- Index hỗ trợ truy vấn danh sách đã hoàn thành
CREATE INDEX shopping_sessions_completed_at_idx ON shopping_sessions (completed_at) WHERE completed_at IS NOT NULL;