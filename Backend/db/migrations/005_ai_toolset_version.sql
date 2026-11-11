-- Bộ công cụ AI v2: chỉ xem/tạo, tham chiếu bằng tên, ẩn ID.
-- Hội thoại cũ (v1) chứa lời gọi công cụ đã bỏ nên không tiếp tục được, vẫn xem lại được.
ALTER TABLE ai_conversations ADD COLUMN toolset_version INTEGER NOT NULL DEFAULT 1;
-- Hành động sửa/xóa còn chờ xác nhận từ bộ cũ: hết hiệu lực
UPDATE ai_actions SET status = 'expired' WHERE status = 'proposed';
