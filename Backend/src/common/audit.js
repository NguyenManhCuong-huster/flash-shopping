import { query } from '../db/pool.js';

const SECRET_KEYS = /password|token|secret|hash|^code$/i;

function scrub(meta) {
  if (!meta || typeof meta !== 'object') return {};
  const out = {};
  for (const [k, v] of Object.entries(meta)) {
    if (SECRET_KEYS.test(k)) continue;
    out[k] = v;
  }
  return out;
}

/**
 * Ghi nhật ký thao tác. Truyền `db` là client giao dịch để log cùng commit/rollback.
 */
export async function audit(db, ctx, action, entityType = null, entityId = null, metadata = {}) {
  const runner = db ?? { query };
  await runner.query(
    `INSERT INTO audit_logs (actor_user_id, action, entity_type, entity_id, metadata, source, ai_action_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [
      ctx?.userId ?? null,
      action,
      entityType,
      entityId,
      JSON.stringify(scrub(metadata)),
      ctx?.source ?? 'app',
      ctx?.aiActionId ?? null,
    ],
  );
}
