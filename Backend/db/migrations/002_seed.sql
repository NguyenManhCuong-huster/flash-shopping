-- Danh mục và đơn vị mặc định (Admin có thể sửa qua admin/category, admin/unit)
INSERT INTO categories (name) VALUES
  ('Thịt'), ('Cá & hải sản'), ('Rau củ'), ('Trái cây'), ('Trứng & sữa'),
  ('Đồ hộp'), ('Đồ khô'), ('Gia vị'), ('Đồ uống'), ('Khác')
ON CONFLICT DO NOTHING;

INSERT INTO units (name) VALUES
  ('kg'), ('g'), ('lít'), ('ml'), ('quả'), ('củ'), ('bó'), ('hộp'), ('gói'), ('chai'), ('cái'), ('lon')
ON CONFLICT DO NOTHING;
