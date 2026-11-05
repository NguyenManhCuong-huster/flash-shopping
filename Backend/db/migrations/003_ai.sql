-- =====================================================================
-- Mô-đun AI Agent (Bảng 22 -> 28 trong báo cáo)
-- =====================================================================

CREATE TABLE ai_conversations (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  group_id   BIGINT REFERENCES groups (id) ON DELETE SET NULL,
  title      VARCHAR(150) NOT NULL DEFAULT 'Cuộc hội thoại mới',
  status     VARCHAR(10) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  summary    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ai_conversations_user_idx ON ai_conversations (user_id, updated_at DESC);

CREATE TABLE ai_messages (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conversation_id BIGINT NOT NULL REFERENCES ai_conversations (id) ON DELETE CASCADE,
  role            VARCHAR(10) NOT NULL CHECK (role IN ('user', 'assistant', 'tool')),
  content         JSONB NOT NULL,
  input_tokens    INTEGER CHECK (input_tokens IS NULL OR input_tokens >= 0),
  output_tokens   INTEGER CHECK (output_tokens IS NULL OR output_tokens >= 0),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ai_messages_conv_idx ON ai_messages (conversation_id, id);

CREATE TABLE ai_actions (
  id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conversation_id      BIGINT NOT NULL REFERENCES ai_conversations (id) ON DELETE CASCADE,
  message_id           BIGINT REFERENCES ai_messages (id) ON DELETE SET NULL,
  user_id              BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  group_id             BIGINT REFERENCES groups (id) ON DELETE SET NULL,
  tool_name            VARCHAR(64) NOT NULL,
  tool_use_id          VARCHAR(100),
  risk_level           VARCHAR(12) NOT NULL CHECK (risk_level IN ('read', 'write', 'destructive')),
  arguments            JSONB NOT NULL,
  summary              VARCHAR(300) NOT NULL,
  status               VARCHAR(12) NOT NULL CHECK (status IN ('proposed', 'executing', 'executed', 'rejected', 'failed', 'expired')),
  depends_on_action_id BIGINT REFERENCES ai_actions (id) ON DELETE SET NULL,
  result_code          VARCHAR(10),
  result               JSONB,
  expires_at           TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  decided_at           TIMESTAMPTZ,
  executed_at          TIMESTAMPTZ,
  CONSTRAINT ai_actions_proposed_expiry_ck CHECK (status <> 'proposed' OR expires_at IS NOT NULL)
);
CREATE INDEX ai_actions_user_status_idx ON ai_actions (user_id, status);
CREATE INDEX ai_actions_conv_idx ON ai_actions (conversation_id, id);

ALTER TABLE audit_logs
  ADD CONSTRAINT audit_logs_ai_action_fk FOREIGN KEY (ai_action_id) REFERENCES ai_actions (id) ON DELETE SET NULL;

CREATE TABLE ai_attachments (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id         BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  conversation_id BIGINT REFERENCES ai_conversations (id) ON DELETE CASCADE,
  file_url        TEXT NOT NULL,
  mime_type       VARCHAR(30) NOT NULL CHECK (mime_type IN ('image/jpeg', 'image/png', 'image/webp')),
  size_bytes      INTEGER NOT NULL CHECK (size_bytes BETWEEN 1 AND 5242880),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ai_user_settings (
  user_id            BIGINT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  enabled            BOOLEAN NOT NULL DEFAULT TRUE,
  auto_execute_level VARCHAR(10) NOT NULL DEFAULT 'read' CHECK (auto_execute_level IN ('read', 'write')),
  daily_token_limit  INTEGER NOT NULL DEFAULT 200000 CHECK (daily_token_limit > 0),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ai_usage_daily (
  user_id       BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  usage_date    DATE NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0,
  input_tokens  BIGINT NOT NULL DEFAULT 0,
  output_tokens BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, usage_date)
);

CREATE TABLE ai_suggestions (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id   BIGINT NOT NULL REFERENCES groups (id) ON DELETE CASCADE,
  type       VARCHAR(30) NOT NULL CHECK (type IN ('expiring_food', 'shopping_from_plan', 'low_stock')),
  dedupe_key VARCHAR(200) NOT NULL,
  title      VARCHAR(200) NOT NULL,
  payload    JSONB NOT NULL,
  status     VARCHAR(10) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'dismissed', 'expired')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  decided_by BIGINT REFERENCES users (id) ON DELETE SET NULL,
  decided_at TIMESTAMPTZ,
  CONSTRAINT ai_suggestions_dedupe_uq UNIQUE (group_id, type, dedupe_key)
);
