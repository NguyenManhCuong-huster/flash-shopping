-- Thêm cột type và verified_at vào email_verifications để hỗ trợ luồng quên mật khẩu (password_reset)
-- phân biệt với luồng xác minh email đăng ký (email_verification).
ALTER TABLE email_verifications
ADD COLUMN IF NOT EXISTS type VARCHAR(50) NOT NULL DEFAULT 'email_verification',
ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ NULL;

-- Chỉ cho phép một token password_reset chưa sử dụng (used_at IS NULL) mỗi user_id/type
CREATE INDEX IF NOT EXISTS idx_email_verifications_user_type_unused
  ON email_verifications (user_id, type) WHERE used_at IS NULL;