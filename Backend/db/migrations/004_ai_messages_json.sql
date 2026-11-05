-- ai_messages.content phải được gửi lại cho LLM đúng từng byte như lần đầu (prompt cache và
-- "preserved thinking" ràng buộc theo nội dung lịch sử). JSONB sắp xếp lại khóa của object,
-- còn JSON lưu nguyên văn bản => dùng JSON cho cột này.
ALTER TABLE ai_messages ALTER COLUMN content TYPE JSON USING content::json;
