/** Chuyển bản ghi users thành DTO công khai (không bao giờ trả password_hash). */
export function toUserDto(u) {
  if (!u) return null;
  return {
    id: u.id,
    email: u.email,
    name: u.name,
    username: u.username,
    language: u.language,
    timezone: u.timezone,
    imageUrl: u.image_url,
    isActive: u.is_active,
    emailVerified: !!u.email_verified_at,
    systemRole: u.system_role,
    createdAt: u.created_at,
  };
}

/** Thông tin rút gọn của thành viên khác (không lộ email). */
export const toMemberDto = (m) => ({
  id: m.id,
  name: m.name,
  username: m.username,
  imageUrl: m.image_url,
  role: m.role,
  joinedAt: m.joined_at,
});
