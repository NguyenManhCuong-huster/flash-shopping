-- Đổi tên cột list_id thành session_id trong bảng shopping_items
-- Thêm cột note (nullable)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'shopping_items' AND column_name = 'list_id'
  ) THEN
    ALTER TABLE shopping_items RENAME COLUMN list_id TO session_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'shopping_items' AND column_name = 'note'
  ) THEN
    ALTER TABLE shopping_items ADD COLUMN note TEXT;
  END IF;
END $$;