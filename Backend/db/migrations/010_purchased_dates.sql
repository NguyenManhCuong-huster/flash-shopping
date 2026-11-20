-- Lưu thời điểm mua của từng mặt hàng khi chuyển vào tủ lạnh.
-- created_at của fridge_items được sử dụng làm storedAt.
ALTER TABLE shopping_items
  RENAME COLUMN bought_quantity TO purchased_quantity;

ALTER TABLE shopping_items
  RENAME COLUMN bought_by TO purchased_by;

ALTER TABLE shopping_items
  RENAME COLUMN bought_at TO purchased_at;

ALTER TABLE fridge_items
  ADD COLUMN IF NOT EXISTS purchased_at TIMESTAMPTZ;
