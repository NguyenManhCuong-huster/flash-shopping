-- Chuyển database đã chạy migration 001 sang tên thuật ngữ mới.
-- Migration 001 đã được cập nhật để database mới tạo thẳng shopping_sessions.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'shopping_lists'
      AND c.relkind = 'r'
      AND n.nspname = 'public'
  ) THEN
    ALTER TABLE shopping_lists RENAME TO shopping_sessions;

    ALTER TABLE shopping_sessions RENAME CONSTRAINT shopping_lists_group_id_uq
      TO shopping_sessions_group_id_uq;
    ALTER INDEX IF EXISTS shopping_lists_group_date_idx
      RENAME TO shopping_sessions_group_date_idx;
    ALTER INDEX IF EXISTS shopping_lists_completed_at_idx
      RENAME TO shopping_sessions_completed_at_idx;
  END IF;
END $$;
