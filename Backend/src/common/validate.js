import { AppError } from './errors.js';

export const isBlank = (v) => v === undefined || v === null || (typeof v === 'string' && v.trim() === '');
export const isPresent = (v) => !isBlank(v);

/** Chuỗi đã trim nếu hợp lệ trong [min, max], ngược lại null. */
export function cleanString(v, { min = 1, max = 255 } = {}) {
  if (typeof v !== 'string' && typeof v !== 'number') return null;
  const s = String(v).normalize('NFC').trim();
  if (s.length < min || s.length > max) return null;
  return s;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
export const isEmail = (v) => typeof v === 'string' && v.length <= 254 && EMAIL_RE.test(v.trim());

export const USERNAME_RE = /^[A-Za-z0-9_.]{4,14}$/;

/** Số dương hữu hạn (chấp nhận chuỗi "1.5"), tối đa 3 chữ số thập phân. */
export function positiveNumber(v) {
  if (v === undefined || v === null || v === '') return null;
  const n = typeof v === 'number' ? v : Number(String(v).replace(',', '.'));
  if (!Number.isFinite(n) || n <= 0 || n >= 1e9) return null;
  return Math.round(n * 1000) / 1000;
}

/** ID nguyên dương (chuỗi hoặc số) -> number, ngược lại null. */
export function toId(v) {
  if (v === undefined || v === null || v === '') return null;
  const s = String(v).trim();
  if (!/^\d{1,15}$/.test(s)) return null;
  const n = Number(s);
  return n > 0 ? n : null;
}

const DATE_RE = /^(\d{4})-(\d{2})-(\d{2})$/;
/** 'YYYY-MM-DD' hợp lệ -> chính chuỗi đó, ngược lại null. */
export function isoDate(v) {
  if (typeof v !== 'string') return null;
  const m = DATE_RE.exec(v.trim());
  if (!m) return null;
  const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
  if (d.getUTCFullYear() !== +m[1] || d.getUTCMonth() !== +m[2] - 1 || d.getUTCDate() !== +m[3]) return null;
  return v.trim();
}

/** Ngày giờ ISO 8601 có múi giờ (hoặc epoch ms) -> Date, ngược lại null. */
export function isoDateTime(v) {
  if (v === undefined || v === null || v === '') return null;
  if (typeof v === 'number' || /^\d{12,14}$/.test(String(v))) {
    const d = new Date(Number(v));
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof v !== 'string') return null;
  const s = v.trim();
  // Bắt buộc có thông tin múi giờ để tránh hiểu nhầm giờ địa phương của server
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})$/.test(s)) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function optionalNote(v, max = 1000) {
  if (v === undefined || v === null) return { ok: true, value: null };
  if (typeof v !== 'string' || v.length > max) return { ok: false };
  const s = v.trim();
  return { ok: true, value: s === '' ? null : s };
}

/** Ném AppError nếu điều kiện sai. */
export function ensure(cond, code, data) {
  if (!cond) throw new AppError(code, data);
}

export function parsePage(q, { defaultLimit = 20, maxLimit = 50 } = {}) {
  const page = Math.max(1, Number.parseInt(q?.page, 10) || 1);
  const limit = Math.min(maxLimit, Math.max(1, Number.parseInt(q?.limit, 10) || defaultLimit));
  return { page, limit, offset: (page - 1) * limit };
}

export const pageMeta = ({ page, limit }, total) => ({ page, limit, total, totalPages: Math.ceil(total / limit) });

/** Chuỗi JSON (form-urlencoded gửi mảng dạng chuỗi) hoặc giá trị gốc. */
export function maybeJson(v) {
  if (typeof v !== 'string') return v;
  try {
    return JSON.parse(v);
  } catch {
    return undefined;
  }
}

export const LOCATIONS = ['cool', 'freezer', 'other'];
export const MEAL_NAMES = ['sáng', 'trưa', 'tối'];

const MEAL_ALIASES = {
  sang: 'sáng', 'sáng': 'sáng', breakfast: 'sáng',
  trua: 'trưa', 'trưa': 'trưa', lunch: 'trưa',
  toi: 'tối', 'tối': 'tối', dinner: 'tối',
};
export function mealName(v) {
  if (typeof v !== 'string') return null;
  return MEAL_ALIASES[v.normalize('NFC').trim().toLowerCase()] ?? null;
}
