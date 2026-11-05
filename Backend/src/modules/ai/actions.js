import Ajv from 'ajv';
import addFormats from 'ajv-formats';
import { query } from '../../db/pool.js';
import { AppError } from '../../common/errors.js';
import { messageOf } from '../../common/codes.js';
import { loadContext } from '../../common/permissions.js';
import { allTools, getTool } from './tools.js';

const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);
const validators = new Map(allTools().map((t) => [t.name, ajv.compile(t.schema)]));

export const CONFIRM_TTL_MINUTES = 15;
const REF_RE = /^\$action:(\d+)\.([A-Za-z]+)$/;

/** Kiểm tra tham số theo JSON Schema của công cụ (additionalProperties = false). */
export function validateArgs(toolName, args) {
  const v = validators.get(toolName);
  if (!v) return { ok: false, errors: ['Công cụ không tồn tại'] };
  const ok = v(args);
  return ok ? { ok: true } : { ok: false, errors: v.errors.map((e) => `${e.instancePath || '(gốc)'} ${e.message}`) };
}

/** Các id hành động được tham chiếu bằng "$action:<id>.<field>" trong tham số. */
export function findRefs(value, out = new Set()) {
  if (typeof value === 'string') {
    const m = REF_RE.exec(value);
    if (m) out.add(Number(m[1]));
  } else if (Array.isArray(value)) value.forEach((v) => findRefs(v, out));
  else if (value && typeof value === 'object') Object.values(value).forEach((v) => findRefs(v, out));
  return out;
}

async function resolveRefs(value, lookup) {
  if (typeof value === 'string') {
    const m = REF_RE.exec(value);
    if (!m) return value;
    const parent = await lookup(Number(m[1]));
    const v = parent?.result?.refs?.[m[2]];
    if (parent?.status !== 'executed' || v === undefined) throw new AppError('00424', { reference: value });
    return v;
  }
  if (Array.isArray(value)) return Promise.all(value.map((v) => resolveRefs(v, lookup)));
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = await resolveRefs(v, lookup);
    return out;
  }
  return value;
}

export const toActionDto = (a) => ({
  actionId: a.id,
  conversationId: a.conversation_id,
  tool: a.tool_name,
  riskLevel: a.risk_level,
  summary: a.summary,
  arguments: a.arguments,
  status: a.status,
  dependsOn: a.depends_on_action_id,
  resultCode: a.result_code,
  result: a.result,
  expiresAt: a.expires_at,
  createdAt: a.created_at,
  decidedAt: a.decided_at,
  executedAt: a.executed_at,
});

export async function createAction({ conversationId, userId, groupId, tool, toolUseId = null, args, status, dependsOn = null }) {
  const { rows } = await query(
    `INSERT INTO ai_actions (conversation_id, user_id, group_id, tool_name, tool_use_id, risk_level, arguments, summary,
                             status, depends_on_action_id, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     RETURNING *`,
    [conversationId, userId, groupId, tool.name, toolUseId, tool.risk, JSON.stringify(args),
      String(tool.summary(args)).slice(0, 300), status, dependsOn,
      status === 'proposed' ? new Date(Date.now() + CONFIRM_TTL_MINUTES * 60_000) : null],
  );
  return rows[0];
}

/**
 * Thực thi một hành động đã ở trạng thái 'executing'.
 * Danh tính và nhóm nạp lại từ CSDL tại thời điểm thực thi (không dùng kết quả kiểm tra lúc đề xuất);
 * Service ghi audit_logs với source = ai và ai_action_id.
 */
export async function executeAction(action) {
  const tool = getTool(action.tool_name);
  const finish = async (status, code, result) => {
    await query(
      `UPDATE ai_actions SET status = $2, result_code = $3, result = $4, executed_at = now() WHERE id = $1`,
      [action.id, status, code, JSON.stringify(result ?? null)],
    );
    return { actionId: action.id, tool: action.tool_name, status, resultCode: code, message: messageOf(code), result };
  };
  try {
    const ctx = await loadContext(action.user_id, { source: 'ai', aiActionId: action.id });
    if (!ctx || !ctx.isActive) return finish('failed', '00017', null);
    const lookup = async (id) =>
      (await query('SELECT status, result FROM ai_actions WHERE id = $1 AND user_id = $2 AND conversation_id = $3', [
        id, action.user_id, action.conversation_id,
      ])).rows[0];
    const args = await resolveRefs(action.arguments, lookup);
    const r = await tool.run(ctx, args);
    const data = tool.compact ? tool.compact(r.data ?? {}) : null;
    const refs = tool.refs ? tool.refs(r.data ?? {}) : {};
    return finish('executed', r.code, { refs, data });
  } catch (err) {
    if (err instanceof AppError) return finish('failed', err.code, { error: err.message, details: err.data ?? null });
    console.error('[ai] thực thi hành động lỗi', err);
    return finish('failed', '00008', null);
  }
}

/** Đánh dấu thất bại các hành động phụ thuộc (đệ quy) khi hành động cha thất bại / bị từ chối. */
export async function failDependents(parentIds, userId) {
  let frontier = [...parentIds];
  const failed = [];
  while (frontier.length) {
    const { rows } = await query(
      `UPDATE ai_actions SET status = 'failed', result_code = '00424', decided_at = now()
        WHERE user_id = $1 AND depends_on_action_id = ANY($2::bigint[]) AND status = 'proposed'
        RETURNING id`,
      [userId, frontier],
    );
    frontier = rows.map((r) => r.id);
    failed.push(...frontier);
  }
  return failed;
}

/** Sắp xếp để hành động cha chạy trước hành động phụ thuộc. */
export function orderByDependency(actions) {
  const byId = new Map(actions.map((a) => [a.id, a]));
  const done = new Set();
  const out = [];
  const visit = (a, depth = 0) => {
    if (done.has(a.id) || depth > 50) return;
    const parent = a.depends_on_action_id && byId.get(a.depends_on_action_id);
    if (parent) visit(parent, depth + 1);
    done.add(a.id);
    out.push(a);
  };
  [...actions].sort((x, y) => x.id - y.id).forEach((a) => visit(a));
  return out;
}
