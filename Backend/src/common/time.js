/** Tiện ích múi giờ IANA dựa trên Intl (không cần thư viện ngoài). */

export function isValidTimeZone(tz) {
  if (typeof tz !== 'string' || tz.length > 64) return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

function offsetMs(date, tz) {
  const dtf = new Intl.DateTimeFormat('en-US', {
    timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  });
  const p = Object.fromEntries(dtf.formatToParts(date).map((x) => [x.type, x.value]));
  const asUtc = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second);
  return asUtc - Math.floor(date.getTime() / 1000) * 1000;
}

/** Giờ địa phương (theo tz) của ngày 'YYYY-MM-DD' -> thời điểm UTC. */
export function zonedDateTimeToUtc(dateStr, hh, mm, ss, tz) {
  const [y, m, d] = dateStr.split('-').map(Number);
  const guess = Date.UTC(y, m - 1, d, hh, mm, ss);
  const off1 = offsetMs(new Date(guess), tz);
  let ts = guess - off1;
  const off2 = offsetMs(new Date(ts), tz);
  if (off2 !== off1) ts = guess - off2;
  return new Date(ts);
}

/** Ngày địa phương 'YYYY-MM-DD' của một thời điểm theo tz. */
export function localDate(date, tz) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' }).format(date);
}

export function addDays(dateStr, n) {
  const [y, m, d] = dateStr.split('-').map(Number);
  const t = new Date(Date.UTC(y, m - 1, d + n));
  return t.toISOString().slice(0, 10);
}

/** Khoảng [start, end) UTC của một ngày địa phương. */
export function dayRange(dateStr, tz) {
  return [zonedDateTimeToUtc(dateStr, 0, 0, 0, tz), zonedDateTimeToUtc(addDays(dateStr, 1), 0, 0, 0, tz)];
}

export function daysBetween(a, b) {
  return Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86400000);
}
