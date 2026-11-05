import cron from 'node-cron';
import { env } from '../../config/env.js';
import { query } from '../../db/pool.js';
import { getPushProvider } from './push.provider.js';

const fmt = (d, tz) =>
  new Intl.DateTimeFormat('vi-VN', {
    timeZone: tz, day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false,
  }).format(d);

const fmtQty = (n) => (Number.isInteger(n) ? String(n) : String(Number(n.toFixed(3))));

/**
 * UC06 bước 1-3: quét thực phẩm còn tồn tới mốc nhắc (trước hạn N ngày) hoặc đã quá hạn,
 * tạo thông báo cho từng thành viên của nhóm với khóa chống trùng (mục + mốc hạn + người nhận).
 * Thực phẩm nhập khi đã còn dưới N ngày (1b): được nhắc ngay ở lần quét kế tiếp, đúng một lần.
 */
export async function scanExpiring({ groupId = null } = {}) {
  const { rows: items } = await query(
    `SELECT fi.id, fi.group_id, fi.use_within, fi.quantity, f.name AS food_name, un.name AS unit_name,
            (fi.use_within < now()) AS expired
       FROM fridge_items fi
       JOIN foods f ON f.id = fi.food_id
       JOIN units un ON un.id = f.unit_id
      WHERE fi.quantity > 0
        AND fi.use_within <= now() + make_interval(days => $1::int)
        AND ($2::bigint IS NULL OR fi.group_id = $2)`,
    [env.expiryReminderDays, groupId],
  );
  if (!items.length) return 0;

  const groupIds = [...new Set(items.map((i) => i.group_id))];
  const { rows: members } = await query(
    `SELECT gm.group_id, u.id AS user_id, u.timezone FROM group_members gm JOIN users u ON u.id = gm.user_id
      WHERE gm.group_id = ANY($1::bigint[]) AND u.is_active`,
    [groupIds],
  );

  let created = 0;
  for (const item of items) {
    const type = item.expired ? 'food_expired' : 'food_expiring';
    const dedupeKey = `${item.id}:${new Date(item.use_within).toISOString()}`;
    for (const m of members.filter((x) => x.group_id === item.group_id)) {
      const when = fmt(new Date(item.use_within), m.timezone);
      const qty = `${fmtQty(item.quantity)} ${item.unit_name}`;
      const title = item.expired ? `Đã hết hạn: ${item.food_name}` : `Sắp hết hạn: ${item.food_name}`;
      const body = item.expired
        ? `${item.food_name} (${qty}) đã hết hạn từ ${when}. Hãy kiểm tra và xử lý.`
        : `${item.food_name} (${qty}) sẽ hết hạn lúc ${when}. Hãy dùng sớm nhé!`;
      const ins = await query(
        `INSERT INTO notifications (user_id, group_id, type, dedupe_key, title, body, data)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (user_id, type, dedupe_key) DO NOTHING RETURNING id`,
        [m.user_id, item.group_id, type, dedupeKey, title, body,
          JSON.stringify({ fridgeItemId: item.id, foodName: item.food_name, screen: 'fridge_item' })],
      );
      created += ins.rowCount;
    }
  }
  if (created) console.log(`[expiry] tạo ${created} thông báo nhắc hạn`);
  await deliverPending();
  return created;
}

/**
 * UC06 bước 4-5: gửi push cho thông báo đang chờ, ghi trạng thái, thử lại có giới hạn.
 * Dùng "thuê" bản ghi (next_attempt_at) + SKIP LOCKED để nhiều instance không gửi trùng.
 */
export async function deliverPending() {
  const provider = getPushProvider();
  const { rows } = await query(
    `UPDATE notifications SET next_attempt_at = now() + interval '5 minutes'
      WHERE id IN (SELECT id FROM notifications
                    WHERE push_status = 'pending' AND (next_attempt_at IS NULL OR next_attempt_at <= now())
                    ORDER BY id LIMIT 200 FOR UPDATE SKIP LOCKED)
      RETURNING *`,
  );
  for (const n of rows) {
    const { rows: devices } = await query('SELECT id, token FROM device_tokens WHERE user_id = $1 AND is_active', [n.user_id]);
    if (!devices.length) {
      await query(`UPDATE notifications SET push_status = 'skipped', last_error = 'no_device' WHERE id = $1`, [n.id]);
      continue;
    }
    let ok = false;
    let transient = false;
    let lastError = null;
    for (const d of devices) {
      const r = await provider.send(d.token, { title: n.title, body: n.body, data: { ...n.data, notificationId: n.id } });
      if (r.status === 'ok') ok = true;
      else {
        lastError = r.error ?? r.status;
        if (r.status === 'invalid') await query('UPDATE device_tokens SET is_active = FALSE, updated_at = now() WHERE id = $1', [d.id]);
        if (r.status === 'retry') transient = true;
      }
    }
    const attempts = n.attempts + 1;
    if (ok) {
      await query(`UPDATE notifications SET push_status = 'sent', sent_at = now(), attempts = $2 WHERE id = $1`, [n.id, attempts]);
    } else if (transient && attempts < env.pushRetryLimit) {
      await query(
        `UPDATE notifications SET attempts = $2, last_error = $3,
                next_attempt_at = now() + make_interval(mins => $4::int) WHERE id = $1`,
        [n.id, attempts, lastError, 2 ** attempts],
      );
    } else {
      await query(`UPDATE notifications SET push_status = 'failed', attempts = $2, last_error = $3 WHERE id = $1`, [
        n.id,
        attempts,
        lastError,
      ]);
    }
  }
}

const pendingGroups = new Map();

/** Quét riêng một nhóm ngay sau khi nhập kho (gộp các lần gọi liên tiếp). */
export function triggerExpiryScan(groupId) {
  if (pendingGroups.has(groupId)) return;
  pendingGroups.set(
    groupId,
    setTimeout(() => {
      pendingGroups.delete(groupId);
      scanExpiring({ groupId }).catch((err) => console.error('[expiry] scan lỗi', err));
    }, 1500),
  );
}

const housekeepers = [];
export const registerHousekeeping = (fn) => housekeepers.push(fn);

export function startExpiryJobs() {
  cron.schedule(env.expiryJobCron, () => {
    scanExpiring().catch((err) => console.error('[expiry] scan lỗi', err));
  });
  // Mỗi phút: gửi lại các push đến hạn thử lại + dọn dẹp
  cron.schedule('* * * * *', async () => {
    try {
      await deliverPending();
      await query(`DELETE FROM idempotency_keys WHERE created_at < now() - interval '7 days'`);
      for (const fn of housekeepers) await fn();
    } catch (err) {
      console.error('[jobs] lỗi', err);
    }
  });
  setTimeout(() => scanExpiring().catch((err) => console.error('[expiry] scan lỗi', err)), 5000);
  console.log(`[jobs] nhắc hạn dùng: cron "${env.expiryJobCron}", trước ${env.expiryReminderDays} ngày, push=${getPushProvider().name}`);
}
