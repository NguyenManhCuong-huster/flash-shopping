import { env } from '../../config/env.js';
import { query, withTx } from '../../db/pool.js';
import { AppError, result, send } from '../../common/errors.js';
import { messageOf, statusOf } from '../../common/codes.js';
import { cleanString, ensure, isoDate, isPresent, maybeJson, pageMeta, parsePage, toId } from '../../common/validate.js';
import { localDate } from '../../common/time.js';
import { removeUploaded } from '../../middlewares/upload.js';
import { aiConfigured, Anthropic } from './llm.gateway.js';
import { allTools, getTool, roleAllows } from './tools.js';
import {
  createAction, executeAction, failDependents, orderByDependency, toActionDto, validateArgs,
} from './actions.js';
import { buildContextText, insertMessage, runTurn } from './orchestrator.js';

const DEFAULT_TITLE = 'Cuộc hội thoại mới';

// ===================== Cài đặt & hạn mức =====================

export async function getSettingsRow(userId) {
  await query('INSERT INTO ai_user_settings (user_id) VALUES ($1) ON CONFLICT DO NOTHING', [userId]);
  return (await query('SELECT * FROM ai_user_settings WHERE user_id = $1', [userId])).rows[0];
}

const settingsDto = (s) => ({
  enabled: s.enabled, autoExecuteLevel: s.auto_execute_level, dailyTokenLimit: s.daily_token_limit, updatedAt: s.updated_at,
});

/** GET ai/settings/ */
export async function getSettings(ctx) {
  return result('00428', { settings: settingsDto(await getSettingsRow(ctx.userId)), aiAvailable: aiConfigured() });
}

/** PUT ai/settings/ {enabled?, autoExecuteLevel?} */
export async function updateSettings(ctx, body = {}) {
  await getSettingsRow(ctx.userId);
  const sets = ['updated_at = now()'];
  const params = [ctx.userId];
  if (body.autoExecuteLevel !== undefined) {
    ensure(['read', 'write'].includes(body.autoExecuteLevel), '00429');
    params.push(body.autoExecuteLevel);
    sets.push(`auto_execute_level = $${params.length}`);
  }
  if (body.enabled !== undefined) {
    ensure(typeof body.enabled === 'boolean' || ['true', 'false'].includes(body.enabled), '00563');
    params.push(body.enabled === true || body.enabled === 'true');
    sets.push(`enabled = $${params.length}`);
  }
  const { rows } = await query(`UPDATE ai_user_settings SET ${sets.join(', ')} WHERE user_id = $1 RETURNING *`, params);
  return result('00430', { settings: settingsDto(rows[0]) });
}

async function todayUsage(ctx) {
  const today = localDate(new Date(), ctx.timezone);
  const r = (await query('SELECT * FROM ai_usage_daily WHERE user_id = $1 AND usage_date = $2', [ctx.userId, today])).rows[0];
  return { today, used: r ? Number(r.input_tokens) + Number(r.output_tokens) : 0 };
}

async function recordUsage(ctx, usage) {
  await query(
    `INSERT INTO ai_usage_daily (user_id, usage_date, request_count, input_tokens, output_tokens) VALUES ($1, $2, 1, $3, $4)
     ON CONFLICT (user_id, usage_date) DO UPDATE SET request_count = ai_usage_daily.request_count + 1,
       input_tokens = ai_usage_daily.input_tokens + EXCLUDED.input_tokens,
       output_tokens = ai_usage_daily.output_tokens + EXCLUDED.output_tokens`,
    [ctx.userId, localDate(new Date(), ctx.timezone), usage.inputTokens, usage.outputTokens],
  );
}

/** GET ai/usage/?from&to */
export async function getUsage(ctx, q = {}) {
  const to = isPresent(q.to) ? isoDate(q.to) : localDate(new Date(), ctx.timezone);
  const from = isPresent(q.from) ? isoDate(q.from) : to;
  ensure(from && to && from <= to, '00541');
  const { rows } = await query(
    `SELECT to_char(usage_date, 'YYYY-MM-DD') AS date, request_count, input_tokens, output_tokens FROM ai_usage_daily
      WHERE user_id = $1 AND usage_date BETWEEN $2::date AND $3::date ORDER BY usage_date`,
    [ctx.userId, from, to],
  );
  const days = rows.map((r) => ({ date: r.date, requests: r.request_count, inputTokens: Number(r.input_tokens), outputTokens: Number(r.output_tokens) }));
  const s = await getSettingsRow(ctx.userId);
  const t = await todayUsage(ctx);
  return result('00435', { from, to, days, dailyTokenLimit: s.daily_token_limit, todayUsed: t.used });
}

// ===================== Hội thoại =====================

async function ownConversation(ctx, rawId) {
  const id = toId(rawId);
  ensure(id, '00409');
  const c = (await query('SELECT * FROM ai_conversations WHERE id = $1', [id])).rows[0];
  ensure(c, '00402');
  ensure(c.user_id === ctx.userId, '00403');
  return c;
}

const convDto = (c) => ({ id: c.id, title: c.title, status: c.status, createdAt: c.created_at, updatedAt: c.updated_at });

async function createConversationRow(ctx, title = DEFAULT_TITLE) {
  const { rows } = await query('INSERT INTO ai_conversations (user_id, group_id, title) VALUES ($1, $2, $3) RETURNING *', [
    ctx.userId, ctx.groupId, title,
  ]);
  return rows[0];
}

/** POST ai/conversation/ {title?} */
export async function createConversation(ctx, body = {}) {
  const title = isPresent(body.title) ? cleanString(body.title, { max: 150 }) : DEFAULT_TITLE;
  ensure(title, '00025');
  return result('00404', { conversation: convDto(await createConversationRow(ctx, title)) });
}

/** GET ai/conversation/?page&limit */
export async function listConversations(ctx, q = {}) {
  const p = parsePage(q, { defaultLimit: 20 });
  const total = (await query('SELECT count(*)::int AS n FROM ai_conversations WHERE user_id = $1', [ctx.userId])).rows[0].n;
  const { rows } = await query(
    `SELECT * FROM ai_conversations WHERE user_id = $1 ORDER BY updated_at DESC LIMIT ${p.limit} OFFSET ${p.offset}`,
    [ctx.userId],
  );
  return result('00405', { conversations: rows.map(convDto), ...pageMeta(p, total) });
}

/** Tin nhắn ở dạng hiển thị (bỏ khối ngữ cảnh, không trả thinking). */
function displayMessage(m) {
  const blocks = Array.isArray(m.content) ? m.content : [];
  const text = blocks.filter((b) => b.type === 'text').map((b) => b.text).join('\n').trim();
  if (m.role === 'tool') {
    const notes = blocks.filter((b) => b.type === 'text').map((b) => b.text);
    return { id: m.id, role: 'tool', text: notes.join('\n'), createdAt: m.created_at };
  }
  return {
    id: m.id,
    role: m.role,
    text,
    attachmentIds: blocks.filter((b) => b.type === 'image' && b.attachmentId).map((b) => b.attachmentId),
    toolCalls: blocks.filter((b) => b.type === 'tool_use').map((b) => b.name),
    createdAt: m.created_at,
  };
}

/** GET ai/conversation/:conversationId/?beforeId&limit */
export async function getConversation(ctx, rawId, q = {}) {
  const c = await ownConversation(ctx, rawId);
  const limit = Math.min(100, Math.max(1, Number.parseInt(q.limit, 10) || 50));
  const beforeId = toId(q.beforeId);
  const { rows } = await query(
    `SELECT * FROM ai_messages WHERE conversation_id = $1 ${beforeId ? 'AND id < $2' : ''} ORDER BY id DESC LIMIT ${limit}`,
    beforeId ? [c.id, beforeId] : [c.id],
  );
  const messages = rows.reverse().map(displayMessage).filter((m) => m.text || m.attachmentIds?.length);
  const actions = (await query('SELECT * FROM ai_actions WHERE conversation_id = $1 ORDER BY id', [c.id])).rows.map(toActionDto);
  return result('00406', { conversation: convDto(c), messages, actions, hasMore: rows.length === limit });
}

/** PUT ai/conversation/ {conversationId, newTitle} */
export async function renameConversation(ctx, body = {}) {
  const c = await ownConversation(ctx, body.conversationId);
  const title = cleanString(body.newTitle, { max: 150 });
  ensure(title, '00025');
  const { rows } = await query('UPDATE ai_conversations SET title = $2, updated_at = now() WHERE id = $1 RETURNING *', [c.id, title]);
  return result('00407', { conversation: convDto(rows[0]) });
}

/** DELETE ai/conversation/ {conversationId} */
export async function deleteConversation(ctx, body = {}) {
  const c = await ownConversation(ctx, body.conversationId);
  ensure(!running.has(c.id), '00437');
  await query('DELETE FROM ai_conversations WHERE id = $1', [c.id]);
  return result('00408');
}

// ===================== Ảnh đính kèm =====================

/** POST ai/attachment/ (multipart image) */
export async function uploadAttachment(ctx, file) {
  ensure(file, '00415');
  const { rows } = await query(
    `INSERT INTO ai_attachments (user_id, file_url, mime_type, size_bytes) VALUES ($1, $2, $3, $4) RETURNING id`,
    [ctx.userId, `private/ai/${file.filename}`, file.mimetype, file.size],
  ).catch((err) => {
    removeUploaded(file);
    throw err;
  });
  return result('00416', { attachmentId: rows[0].id, mimeType: file.mimetype, sizeBytes: file.size });
}

// ===================== Chat =====================

/** Mỗi cuộc hội thoại chỉ xử lý một lượt tại một thời điểm (00437); giữ AbortController để hủy (00438). */
const running = new Map();

async function prepareChat(ctx, body) {
  const message = typeof body.message === 'string' ? body.message.trim() : '';
  ensure(message, '00400');
  ensure(message.length <= 4000, '00401');
  const settings = await getSettingsRow(ctx.userId);
  ensure(settings.enabled, '00411');
  const usage = await todayUsage(ctx);
  ensure(usage.used < settings.daily_token_limit, '00412');
  ensure(aiConfigured(), '00413');

  const conversation = body.conversationId === undefined || body.conversationId === null || body.conversationId === ''
    ? await createConversationRow(ctx)
    : await ownConversation(ctx, body.conversationId);
  ensure(!running.has(conversation.id), '00437');

  const ids = maybeJson(body.attachmentIds) ?? [];
  ensure(Array.isArray(ids) && ids.length <= 5, '00417');
  const attachmentIds = ids.map(toId);
  ensure(attachmentIds.every(Boolean), '00417');
  if (attachmentIds.length) {
    const { rows } = await query(
      `UPDATE ai_attachments SET conversation_id = $3
        WHERE id = ANY($1::bigint[]) AND user_id = $2 AND (conversation_id IS NULL OR conversation_id = $3) RETURNING id`,
      [attachmentIds, ctx.userId, conversation.id],
    );
    ensure(rows.length === attachmentIds.length, '00417');
  }
  const userBlocks = [
    { type: 'context', text: buildContextText(ctx, body.clientContext) },
    ...attachmentIds.map((id) => ({ type: 'image', attachmentId: id })),
    { type: 'text', text: message },
  ];
  return { message, settings, conversation, userBlocks };
}

/** POST ai/chat/ - JSON (stream=false) hoặc text/event-stream (stream=true). */
export async function chat(req, res) {
  const ctx = req.ctx;
  const body = req.body ?? {};
  const wantStream = body.stream === true || body.stream === 'true';
  const prep = await prepareChat(ctx, body);
  const conversationId = prep.conversation.id;

  const controller = new AbortController();
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, env.ai.turnTimeoutMs);
  running.set(conversationId, controller);

  let emit = () => {};
  if (wantStream) {
    res.status(200).set({ 'Content-Type': 'text/event-stream; charset=utf-8', 'Cache-Control': 'no-cache', Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
    res.flushHeaders();
    emit = (event, data) => {
      if (!res.writableEnded) res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
    };
    // Ứng dụng ngắt kết nối giữa chừng => hủy lượt để không tốn token
    res.on('close', () => {
      if (!res.writableFinished) controller.abort();
    });
    emit('conversation', { conversationId });
  }

  try {
    if (prep.conversation.title === DEFAULT_TITLE) {
      await query('UPDATE ai_conversations SET title = $2 WHERE id = $1', [conversationId, prep.message.slice(0, 60)]);
    }
    const out = await runTurn({ ctx, conversationId, userBlocks: prep.userBlocks, settings: prep.settings, emit, signal: controller.signal });
    await recordUsage(ctx, out.usage);
    const data = {
      conversationId,
      message: { id: out.messageId, role: 'assistant', content: out.text },
      executedActions: out.executedActions,
      pendingActions: out.pendingActions,
      usage: out.usage,
    };
    if (wantStream) {
      emit('message.completed', { messageId: out.messageId, usage: out.usage, text: out.text, pendingActions: out.pendingActions });
      res.end();
    } else send(res, result('00410', data));
  } catch (err) {
    let code = '00413';
    if (err instanceof AppError) code = err.code;
    else if (err instanceof Anthropic.APIUserAbortError || controller.signal.aborted) code = timedOut ? '00414' : '00438';
    else if (err instanceof Anthropic.APIError) console.error(`[ai] LLM lỗi ${err.status}: ${err.message}`);
    else console.error('[ai] lỗi lượt hội thoại', err);
    if (wantStream) {
      emit('error', { code, message: messageOf(code) });
      res.end();
    } else if (!res.headersSent) {
      res.status(statusOf(code)).json({ code, message: messageOf(code), data: { conversationId } });
    }
  } finally {
    clearTimeout(timer);
    running.delete(conversationId);
  }
}

/** POST ai/chat/cancel/ {conversationId} */
export async function cancelTurn(ctx, body = {}) {
  const c = await ownConversation(ctx, body.conversationId);
  running.get(c.id)?.abort();
  return result('00438', { conversationId: c.id, wasRunning: running.has(c.id) });
}

// ===================== Hành động =====================

/** GET ai/action/?conversationId&status */
export async function listActions(ctx, q = {}) {
  const params = [ctx.userId];
  let w = 'user_id = $1';
  if (q.conversationId !== undefined) {
    const c = await ownConversation(ctx, q.conversationId);
    params.push(c.id);
    w += ` AND conversation_id = $${params.length}`;
  }
  if (['proposed', 'executing', 'executed', 'rejected', 'failed', 'expired'].includes(q.status)) {
    params.push(q.status);
    w += ` AND status = $${params.length}`;
  }
  const { rows } = await query(`SELECT * FROM ai_actions WHERE ${w} ORDER BY id DESC LIMIT 100`, params);
  return result('00426', { actions: rows.map(toActionDto) });
}

function parseActionIds(raw) {
  const ids = maybeJson(raw);
  ensure(Array.isArray(ids) && ids.length > 0 && ids.length <= 20, '00418');
  const parsed = ids.map(toId);
  ensure(parsed.every(Boolean), '00418');
  return [...new Set(parsed)];
}

/** Ghi kết quả xác nhận/từ chối vào hội thoại (role = tool) để lượt sau AI biết. */
async function appendOutcomeNote(conversationIds, lines) {
  for (const convId of conversationIds) {
    const text = lines.filter((l) => l.convId === convId).map((l) => l.text).join('\n');
    if (text) await insertMessage({ query }, convId, 'tool', [{ type: 'text', text: `[Kết quả từ ứng dụng]\n${text}` }]);
  }
}

/**
 * POST ai/action/confirm/ {actionIds, editedArguments?: {"<actionId>": {...}}}
 * Chuyển trạng thái nguyên tử proposed -> executing (mỗi hành động chỉ chạy một lần), chạy theo thứ tự phụ thuộc.
 */
export async function confirmActions(ctx, body = {}) {
  const ids = parseActionIds(body.actionIds);
  const edited = maybeJson(body.editedArguments) ?? {};
  ensure(edited && typeof edited === 'object' && !Array.isArray(edited), '00422');
  const { rows } = await query('SELECT * FROM ai_actions WHERE id = ANY($1::bigint[]) AND user_id = $2', [ids, ctx.userId]);
  ensure(rows.length === ids.length, '00419');

  // Kiểm tra toàn bộ tham số đã sửa trước khi chạy bất kỳ hành động nào
  for (const [key, args] of Object.entries(edited)) {
    const a = rows.find((r) => String(r.id) === key);
    ensure(a, '00419');
    ensure(validateArgs(a.tool_name, args).ok, '00422', { actionId: a.id });
  }

  const results = [];
  const notes = [];
  for (const a of orderByDependency(rows)) {
    const args = edited[String(a.id)] ?? a.arguments;
    const claimed = (
      await query(
        `UPDATE ai_actions SET status = 'executing', decided_at = now(), arguments = $3
          WHERE id = $1 AND user_id = $2 AND status = 'proposed' AND expires_at > now() RETURNING *`,
        [a.id, ctx.userId, JSON.stringify(args)],
      )
    ).rows[0];
    if (!claimed) {
      const cur = (await query('SELECT status, expires_at FROM ai_actions WHERE id = $1', [a.id])).rows[0];
      let code = '00420';
      if (cur.status === 'proposed') {
        await query(`UPDATE ai_actions SET status = 'expired' WHERE id = $1 AND status = 'proposed'`, [a.id]);
        code = '00421';
      }
      // Không chạy lại trong yêu cầu này (đã xử lý / hết hạn) => không tính là thành công
      results.push({ actionId: a.id, status: code === '00421' ? 'expired' : cur.status, skipped: true, resultCode: code, message: messageOf(code) });
      continue;
    }
    if (claimed.depends_on_action_id) {
      const parent = (await query('SELECT status FROM ai_actions WHERE id = $1', [claimed.depends_on_action_id])).rows[0];
      if (parent?.status !== 'executed') {
        await query(`UPDATE ai_actions SET status = 'failed', result_code = '00424' WHERE id = $1`, [a.id]);
        results.push({ actionId: a.id, status: 'failed', resultCode: '00424', message: 'Hành động phụ thuộc chưa được thực hiện' });
        notes.push({ convId: a.conversation_id, text: `- #${a.id} ${a.summary}: thất bại vì hành động #${claimed.depends_on_action_id} chưa thực hiện` });
        continue;
      }
    }
    const r = await executeAction(claimed);
    results.push(r);
    notes.push({
      convId: a.conversation_id,
      text: `- #${a.id} ${a.summary}: ${r.status === 'executed' ? 'đã thực hiện' : 'thất bại'} (${r.resultCode} ${r.message})${r.result?.refs && Object.keys(r.result.refs).length ? ` ${JSON.stringify(r.result.refs)}` : ''}`,
    });
    if (r.status === 'failed') await failDependents([a.id], ctx.userId);
  }
  await appendOutcomeNote([...new Set(rows.map((r) => r.conversation_id))], notes);
  const allOk = results.every((r) => r.status === 'executed' && !r.skipped);
  return result(allOk ? '00423' : '00424', { results });
}

/** POST ai/action/reject/ {actionIds, reason?} */
export async function rejectActions(ctx, body = {}) {
  const ids = parseActionIds(body.actionIds);
  const reason = cleanString(body.reason ?? '', { min: 0, max: 300 }) ?? '';
  const { rows } = await query(
    `UPDATE ai_actions SET status = 'rejected', decided_at = now(), result = $3
      WHERE id = ANY($1::bigint[]) AND user_id = $2 AND status = 'proposed' RETURNING *`,
    [ids, ctx.userId, JSON.stringify({ reason })],
  );
  ensure(rows.length, '00420');
  const failed = await failDependents(rows.map((r) => r.id), ctx.userId);
  await appendOutcomeNote(
    [...new Set(rows.map((r) => r.conversation_id))],
    rows.map((r) => ({ convId: r.conversation_id, text: `- #${r.id} ${r.summary}: người dùng từ chối${reason ? ` (lý do: ${reason})` : ''}` })),
  );
  return result('00425', { rejected: rows.map((r) => r.id), failedDependents: failed });
}

/** GET ai/tools/ */
export async function listTools(ctx) {
  return result('00427', {
    tools: allTools().map((t) => ({ name: t.name, description: t.description, riskLevel: t.risk, allowedForMe: roleAllows(t, ctx) })),
  });
}

// ===================== Gợi ý chủ động =====================

const suggestionDto = (s) => ({
  id: s.id, type: s.type, title: s.title, payload: s.payload, status: s.status, createdAt: s.created_at, expiresAt: s.expires_at,
});

/** Chỉ hiện gợi ý cho thành viên có quyền thực hiện mọi hành động trong payload. */
const canActOn = (ctx, s) => (s.payload?.actions ?? []).every((a) => {
  const t = getTool(a.tool);
  return t && roleAllows(t, ctx);
});

/** GET ai/suggestion/?status */
export async function listSuggestions(ctx, q = {}) {
  if (!ctx.groupId) return result('00431', { suggestions: [] });
  const status = ['pending', 'accepted', 'dismissed', 'expired'].includes(q.status) ? q.status : 'pending';
  const { rows } = await query(
    `SELECT * FROM ai_suggestions WHERE group_id = $1 AND status = $2 ORDER BY created_at DESC LIMIT 50`,
    [ctx.groupId, status],
  );
  return result('00431', { suggestions: rows.filter((s) => canActOn(ctx, s)).map(suggestionDto) });
}

async function claimSuggestion(ctx, rawId, status) {
  const id = toId(rawId);
  ensure(id && ctx.groupId, '00432');
  const s = (await query(`SELECT * FROM ai_suggestions WHERE id = $1 AND group_id = $2 AND status = 'pending' AND expires_at > now()`, [
    id, ctx.groupId,
  ])).rows[0];
  ensure(s && canActOn(ctx, s), '00432');
  const upd = await query(
    `UPDATE ai_suggestions SET status = $2, decided_by = $3, decided_at = now() WHERE id = $1 AND status = 'pending' RETURNING *`,
    [id, status, ctx.userId],
  );
  ensure(upd.rowCount, '00432');
  return upd.rows[0];
}

/** POST ai/suggestion/dismiss/ {suggestionId} */
export async function dismissSuggestion(ctx, body = {}) {
  await claimSuggestion(ctx, body.suggestionId, 'dismissed');
  return result('00433');
}

/**
 * POST ai/suggestion/accept/ {suggestionId}
 * Tạo hội thoại mới chứa tóm tắt gợi ý và chuyển payload thành các ai_actions 'proposed';
 * người dùng vẫn xác nhận qua ai/action/confirm/. "$ref:<i>.<field>" trong payload trỏ tới hành động thứ i.
 */
export async function acceptSuggestion(ctx, body = {}) {
  const s = await claimSuggestion(ctx, body.suggestionId, 'accepted');
  const out = await withTx(async (db) => {
    const conv = (
      await db.query('INSERT INTO ai_conversations (user_id, group_id, title) VALUES ($1, $2, $3) RETURNING *', [
        ctx.userId, ctx.groupId, s.title.slice(0, 150),
      ])
    ).rows[0];
    await insertMessage(db, conv.id, 'tool', [{
      type: 'text',
      text: `[Gợi ý chủ động từ ứng dụng] ${s.title}\nNgười dùng đã chấp nhận gợi ý; các hành động dưới đây đang chờ xác nhận.`,
    }]);
    return conv;
  });
  const created = [];
  for (const a of s.payload.actions ?? []) {
    const tool = getTool(a.tool);
    if (!tool) continue;
    let dependsOn = null;
    const args = JSON.parse(
      JSON.stringify(a.arguments).replace(/"\$ref:(\d+)\.([A-Za-z]+)"/g, (_m, i, f) => {
        const parent = created[Number(i)];
        dependsOn = parent?.id ?? dependsOn;
        return parent ? `"$action:${parent.id}.${f}"` : 'null';
      }),
    );
    created.push(await createAction({ conversationId: out.id, userId: ctx.userId, groupId: ctx.groupId, tool, args, status: 'proposed', dependsOn }));
  }
  await insertMessage({ query }, out.id, 'tool', [{
    type: 'text',
    text: `Các hành động đề xuất: ${created.map((a) => `#${a.id} ${a.summary}`).join('; ')}`,
  }]);
  return result('00434', { conversationId: out.id, pendingActions: created.map(toActionDto) });
}

// ===================== Quản trị =====================

/** GET admin/ai/logs/?userId&status&from&to&page&limit */
export async function adminLogs(ctx, q = {}) {
  const p = parsePage(q, { defaultLimit: 50 });
  const params = [];
  const where = [];
  const add = (sql, v) => {
    params.push(v);
    where.push(sql.replace('?', `$${params.length}`));
  };
  if (toId(q.userId)) add('a.user_id = ?', toId(q.userId));
  if (isPresent(q.status)) add('a.status = ?', String(q.status));
  if (isoDate(q.from)) add('a.created_at >= ?::date', q.from);
  if (isoDate(q.to)) add('a.created_at < (?::date + 1)', q.to);
  const w = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const total = (await query(`SELECT count(*)::int AS n FROM ai_actions a ${w}`, params)).rows[0].n;
  const { rows } = await query(
    `SELECT a.*, u.email, u.name FROM ai_actions a JOIN users u ON u.id = a.user_id ${w}
      ORDER BY a.id DESC LIMIT ${p.limit} OFFSET ${p.offset}`,
    params,
  );
  return result('00436', {
    actions: rows.map((r) => ({ ...toActionDto(r), user: { id: r.user_id, email: r.email, name: r.name } })),
    ...pageMeta(p, total),
  });
}
