/** NFR02: ngày dd/MM/yyyy, số lượng luôn kèm đơn vị. */

const pad = (n: number) => String(n).padStart(2, '0');

export const isoDate = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export const parseIso = (s: string) => {
  const [y, m, d] = s.split('-').map(Number);
  return new Date(y, m - 1, d);
};
export const addDays = (d: Date, n: number) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
export const today = () => {
  const d = new Date();
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
};

export const fmtDate = (v: string | Date) => {
  const d = typeof v === 'string' ? (v.length === 10 ? parseIso(v) : new Date(v)) : v;
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()}`;
};
export const fmtDateTime = (v: string) => {
  const d = new Date(v);
  return `${fmtDate(d)} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
};
export const fmtWeekday = (d: Date) => ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'][d.getDay()];

export const fmtQty = (n: number) => String(Math.round(n * 1000) / 1000).replace('.', ',');
export const qtyUnit = (n: number, unit: string) => `${fmtQty(n)} ${unit}`;
export const parseQty = (s: string) => {
  const n = Number(s.trim().replace(',', '.'));
  return Number.isFinite(n) ? n : NaN;
};

export function relativeTime(v: string) {
  const s = (Date.now() - new Date(v).getTime()) / 1000;
  if (s < 60) return 'vừa xong';
  if (s < 3600) return `${Math.floor(s / 60)} phút trước`;
  if (s < 86400) return `${Math.floor(s / 3600)} giờ trước`;
  if (s < 7 * 86400) return `${Math.floor(s / 86400)} ngày trước`;
  return fmtDate(v);
}

export const statusLabel = (status: string, daysLeft: number) =>
  status === 'expired' ? 'Đã hết hạn' : daysLeft <= 0 ? 'Hết hạn hôm nay' : `Còn ${daysLeft} ngày`;

/** Khóa chống lặp cho xác nhận mua. */
export const newKey = () => crypto.randomUUID();

/** Mỗi dòng cách làm -> một đoạn <p>; ký tự HTML được thoát. */
export const stepsToHtml = (text: string) =>
  text
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean)
    .map((l) => `<p>${l.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}</p>`)
    .join('');

export const htmlToSteps = (html?: string) =>
  (html ?? '')
    .replace(/<\/(p|li|h\d|blockquote)>/gi, '\n')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&')
    .trim();
