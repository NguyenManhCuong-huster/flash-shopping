-- =====================================================================
-- Đi chợ tiện lợi - Lược đồ lõi (Bảng 8 -> 21 trong báo cáo)
-- Các phần đánh dấu [BỔ SUNG] là mở rộng so với báo cáo để hiện thực
-- UC04 (xác nhận mua), UC05 (tiêu thụ), UC06 (nhắc hạn), UC09, UC10.
-- =====================================================================

-- ---------- Tài khoản ----------
CREATE TABLE users (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email             VARCHAR(254) NOT NULL,
  password_hash     TEXT NOT NULL,
  name              VARCHAR(29) NOT NULL CHECK (char_length(name) BETWEEN 4 AND 29),
  username          VARCHAR(14) UNIQUE CHECK (username IS NULL OR char_length(username) BETWEEN 4 AND 14),
  language          VARCHAR(10) NOT NULL DEFAULT 'vi',
  timezone          VARCHAR(64) NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
  device_id         TEXT,
  image_url         TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  email_verified_at TIMESTAMPTZ,
  system_role       VARCHAR(10) NOT NULL DEFAULT 'user' CHECK (system_role IN ('user', 'admin')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- UNIQUE không phân biệt hoa thường
CREATE UNIQUE INDEX users_email_lower_uq ON users (lower(email));

-- ---------- Nhóm gia đình ----------
CREATE TABLE groups (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100) NOT NULL DEFAULT 'Gia đình',   -- [BỔ SUNG] tên hiển thị
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE group_members (
  group_id  BIGINT NOT NULL REFERENCES groups (id) ON DELETE CASCADE,
  user_id   BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  role      VARCHAR(10) NOT NULL CHECK (role IN ('admin', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id),
  -- Một người thuộc tối đa một nhóm (mã 00093, 00099)
  CONSTRAINT group_members_user_uq UNIQUE (user_id)
);
-- Mỗi nhóm tối đa một trưởng nhóm (role = admin)
CREATE UNIQUE INDEX group_members_one_admin_uq ON group_members (group_id) WHERE role = 'admin';

-- ---------- Danh mục dùng chung (Admin quản lý) ----------
CREATE TABLE categories (
  id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(100) NOT NULL CHECK (btrim(name) <> '')
);
CREATE UNIQUE INDEX categories_name_uq ON categories (lower(btrim(name)));

CREATE TABLE units (
  id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(100) NOT NULL CHECK (btrim(name) <> '')
);
CREATE UNIQUE INDEX units_name_uq ON units (lower(btrim(name)));

-- ---------- Thực phẩm ----------
CREATE TABLE foods (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id    BIGINT NOT NULL REFERENCES groups (id) ON DELETE CASCADE,
  category_id BIGINT NOT NULL REFERENCES categories (id) ON DELETE RESTRICT,
  unit_id     BIGINT NOT NULL REFERENCES units (id) ON DELETE RESTRICT,
  name        VARCHAR(150) NOT NULL CHECK (btrim(name) <> ''),
  image_url   TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT foods_group_id_uq UNIQUE (group_id, id)
);
-- Báo cáo đề xuất UNIQUE toàn hệ thống; ở đây chọn phương án "phạm vi nhóm" mà báo cáo
-- cũng nêu (mọi API tra theo tên đều đã gắn group_id lấy từ token).
CREATE UNIQUE INDEX foods_group_name_uq ON foods (group_id, lower(btrim(name)));

-- ---------- Tủ lạnh ----------
CREATE TABLE fridge_items (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id   BIGINT NOT NULL REFERENCES groups (id) ON DELETE CASCADE,
  food_id    BIGINT NOT NULL,
  quantity   NUMERIC(12, 3) NOT NULL CHECK (quantity > 0),
  use_within TIMESTAMPTZ NOT NULL,
  location   VARCHAR(10) NOT NULL DEFAULT 'cool' CHECK (location IN ('cool', 'freezer', 'other')), -- [BỔ SUNG] vị trí
  note       TEXT,
  version    INTEGER NOT NULL DEFAULT 1,      -- [BỔ SUNG] kiểm soát cập nhật đồng thời (UC05 - 4b)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (group_id, food_id) REFERENCES foods (group_id, id) ON DELETE CASCADE,
  -- Mỗi nhóm có tối đa một mục tủ lạnh cho một thực phẩm (không chia lô)
  CONSTRAINT fridge_items_group_food_uq UNIQUE (group_id, food_id)
);
CREATE INDEX fridge_items_use_within_idx ON fridge_items (use_within);

-- ---------- Công thức ----------
CREATE TABLE recipes (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id     BIGINT NOT NULL,                                     -- [BỔ SUNG] phạm vi nhóm
  food_id      BIGINT NOT NULL,
  created_by   BIGINT REFERENCES users (id) ON DELETE SET NULL,
  name         VARCHAR(150) NOT NULL CHECK (btrim(name) <> ''),
  description  TEXT NOT NULL,
  html_content TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (group_id, food_id) REFERENCES foods (group_id, id) ON DELETE CASCADE,
  CONSTRAINT recipes_group_id_uq UNIQUE (group_id, id)
);
CREATE INDEX recipes_food_idx ON recipes (food_id);

-- [BỔ SUNG] Nguyên liệu phụ của công thức, cần cho UC08/UC09 (đối chiếu tồn kho, nguyên liệu thiếu).
-- recipes.food_id vẫn là nguyên liệu chính như báo cáo.
CREATE TABLE recipe_ingredients (
  recipe_id BIGINT NOT NULL,
  group_id  BIGINT NOT NULL,
  food_id   BIGINT NOT NULL,
  quantity  NUMERIC(12, 3) CHECK (quantity IS NULL OR quantity > 0),
  PRIMARY KEY (recipe_id, food_id),
  FOREIGN KEY (group_id, recipe_id) REFERENCES recipes (group_id, id) ON DELETE CASCADE,
  FOREIGN KEY (group_id, food_id) REFERENCES foods (group_id, id) ON DELETE CASCADE
);

-- ---------- Kế hoạch bữa ăn ----------
CREATE TABLE meal_plans (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id   BIGINT NOT NULL REFERENCES groups (id) ON DELETE CASCADE,
  food_id    BIGINT NOT NULL,
  recipe_id  BIGINT REFERENCES recipes (id) ON DELETE SET NULL,     -- [BỔ SUNG] món chọn theo công thức
  planned_at TIMESTAMPTZ NOT NULL,
  meal_name  VARCHAR(10) NOT NULL CHECK (meal_name IN ('sáng', 'trưa', 'tối')),
  created_by BIGINT REFERENCES users (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (group_id, food_id) REFERENCES foods (group_id, id) ON DELETE CASCADE
);
CREATE INDEX meal_plans_group_time_idx ON meal_plans (group_id, planned_at);

-- ---------- Mua sắm ----------
CREATE TABLE shopping_lists (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id         BIGINT NOT NULL REFERENCES groups (id) ON DELETE CASCADE,
  assigned_user_id BIGINT,          -- NULL = chưa giao (UC03: "người được giao nếu có")
  name             VARCHAR(150) NOT NULL CHECK (btrim(name) <> ''),
  note             TEXT,
  shopping_date    DATE NOT NULL,
  created_by       BIGINT REFERENCES users (id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT shopping_lists_group_id_uq UNIQUE (group_id, id),
  -- Người được giao phải là thành viên cùng nhóm; rời nhóm => bỏ giao
  FOREIGN KEY (group_id, assigned_user_id) REFERENCES group_members (group_id, user_id)
    ON DELETE SET NULL (assigned_user_id)
);
CREATE INDEX shopping_lists_group_date_idx ON shopping_lists (group_id, shopping_date DESC);

CREATE TABLE shopping_tasks (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  list_id         BIGINT NOT NULL,
  group_id        BIGINT NOT NULL,
  food_id         BIGINT NOT NULL,
  quantity        NUMERIC(12, 3) NOT NULL CHECK (quantity > 0),
  -- [BỔ SUNG] trạng thái mua (UC04)
  status          VARCHAR(10) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'bought')),
  bought_quantity NUMERIC(12, 3) CHECK (bought_quantity IS NULL OR bought_quantity > 0),
  bought_by       BIGINT REFERENCES users (id) ON DELETE SET NULL,
  bought_at       TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (group_id, list_id) REFERENCES shopping_lists (group_id, id) ON DELETE CASCADE,
  FOREIGN KEY (group_id, food_id) REFERENCES foods (group_id, id) ON DELETE CASCADE,
  CONSTRAINT shopping_tasks_list_food_uq UNIQUE (list_id, food_id)
);

-- [BỔ SUNG] Lịch sử biến động kho (Stock Events) phục vụ UC04, UC05, UC10.
-- Lưu bản chụp tên/đơn vị/danh mục để thống kê vẫn đúng sau khi thực phẩm bị xóa.
CREATE TABLE stock_events (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id         BIGINT NOT NULL REFERENCES groups (id) ON DELETE CASCADE,
  food_id          BIGINT REFERENCES foods (id) ON DELETE SET NULL,
  food_name        VARCHAR(150) NOT NULL,
  unit_name        VARCHAR(100) NOT NULL,
  category_name    VARCHAR(100) NOT NULL,
  type             VARCHAR(10) NOT NULL CHECK (type IN ('purchase', 'add', 'consume', 'discard', 'adjust', 'remove')),
  quantity         NUMERIC(12, 3) NOT NULL,   -- adjust: có dấu; các loại khác: số dương
  actor_user_id    BIGINT REFERENCES users (id) ON DELETE SET NULL,
  shopping_task_id BIGINT,
  note             TEXT,
  occurred_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX stock_events_group_time_idx ON stock_events (group_id, occurred_at DESC);

-- [BỔ SUNG] Khóa chống lặp (NFR10)
CREATE TABLE idempotency_keys (
  user_id      BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  key          VARCHAR(100) NOT NULL,
  endpoint     VARCHAR(100) NOT NULL,
  request_hash TEXT NOT NULL,
  status_code  INTEGER,
  response     JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, key)
);

-- ---------- Dữ liệu xác thực ----------
CREATE TABLE auth_sessions (
  id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id            BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  refresh_token_hash TEXT NOT NULL UNIQUE,
  expires_at         TIMESTAMPTZ NOT NULL,
  revoked_at         TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX auth_sessions_user_idx ON auth_sessions (user_id);

CREATE TABLE email_verifications (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  code_hash     TEXT NOT NULL,
  token_hash    TEXT NOT NULL UNIQUE,
  expires_at    TIMESTAMPTZ NOT NULL,
  used_at       TIMESTAMPTZ,
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Thông báo đẩy (UC06) [BỔ SUNG] ----------
CREATE TABLE device_tokens (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token      TEXT NOT NULL UNIQUE,
  platform   VARCHAR(10) NOT NULL DEFAULT 'android',
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE notifications (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id         BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  group_id        BIGINT REFERENCES groups (id) ON DELETE CASCADE,
  type            VARCHAR(30) NOT NULL,
  dedupe_key      VARCHAR(200) NOT NULL,
  title           VARCHAR(200) NOT NULL,
  body            TEXT NOT NULL,
  data            JSONB NOT NULL DEFAULT '{}'::jsonb,
  push_status     VARCHAR(10) NOT NULL DEFAULT 'pending' CHECK (push_status IN ('pending', 'sent', 'failed', 'skipped')),
  attempts        INTEGER NOT NULL DEFAULT 0,
  last_error      TEXT,
  next_attempt_at TIMESTAMPTZ,
  read_at         TIMESTAMPTZ,
  sent_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Khóa chống trùng theo mục, mốc nhắc và người nhận
  CONSTRAINT notifications_dedupe_uq UNIQUE (user_id, type, dedupe_key)
);
CREATE INDEX notifications_user_idx ON notifications (user_id, created_at DESC);
CREATE INDEX notifications_retry_idx ON notifications (push_status, next_attempt_at);

-- ---------- Nhật ký hệ thống ----------
CREATE TABLE audit_logs (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_user_id BIGINT REFERENCES users (id) ON DELETE SET NULL,
  action        VARCHAR(100) NOT NULL,
  entity_type   VARCHAR(64),
  entity_id     BIGINT,
  occurred_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata      JSONB NOT NULL DEFAULT '{}'::jsonb,
  source        VARCHAR(10) NOT NULL DEFAULT 'app' CHECK (source IN ('app', 'ai', 'system')),
  ai_action_id  BIGINT        -- FK được thêm ở migration AI
);
CREATE INDEX audit_logs_time_idx ON audit_logs (occurred_at DESC);
