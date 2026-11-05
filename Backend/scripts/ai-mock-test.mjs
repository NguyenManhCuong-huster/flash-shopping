/**
 * Kiểm thử vòng lặp AI Agent mà KHÔNG gọi LLM thật (không tốn phí):
 * dựng một mock Messages API trả SSE theo kịch bản, chạy API với AI_BASE_URL trỏ vào mock.
 *
 *   1) node scripts/ai-mock-test.mjs --mock            (chạy mock ở cổng 4010)
 *   2) chạy API: AI_API_KEY=dummy AI_BASE_URL=http://localhost:4010 PORT=3002 ... node src/server.js
 *   3) node scripts/ai-mock-test.mjs                   (chạy kịch bản, cần DATABASE_URL để đánh dấu đã xác minh email)
 * Hoặc chạy cả gói: node scripts/ai-mock-test.mjs --all
 */
import http from 'node:http';
import { spawn } from 'node:child_process';
import pg from 'pg';

const MOCK_PORT = 4010;
const API = process.env.API_URL || 'http://localhost:3002';
const DB = process.env.DATABASE_URL || 'postgres://dicho:dicho@localhost:5433/dicho';
const requests = [];

// ---------------- Mock Messages API ----------------
function sse(res, blocks, stopReason) {
  const send = (event, data) => res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
  res.writeHead(200, { 'Content-Type': 'text/event-stream' });
  send('message_start', {
    type: 'message_start',
    message: { id: `msg_${requests.length}`, type: 'message', role: 'assistant', model: 'mock', content: [], stop_reason: null, stop_sequence: null, usage: { input_tokens: 100, output_tokens: 1 } },
  });
  blocks.forEach((b, index) => {
    if (b.type === 'text') {
      send('content_block_start', { type: 'content_block_start', index, content_block: { type: 'text', text: '' } });
      for (const piece of b.text.match(/.{1,12}/gs)) send('content_block_delta', { type: 'content_block_delta', index, delta: { type: 'text_delta', text: piece } });
    } else {
      send('content_block_start', { type: 'content_block_start', index, content_block: { type: 'tool_use', id: b.id, name: b.name, input: {} } });
      send('content_block_delta', { type: 'content_block_delta', index, delta: { type: 'input_json_delta', partial_json: JSON.stringify(b.input) } });
    }
    send('content_block_stop', { type: 'content_block_stop', index });
  });
  send('message_delta', { type: 'message_delta', delta: { stop_reason: stopReason, stop_sequence: null }, usage: { output_tokens: 42 } });
  send('message_stop', { type: 'message_stop' });
  res.end();
}

/** Kịch bản: xem tủ lạnh -> đề xuất tạo danh sách -> đề xuất thêm món (tham chiếu $action) -> trả lời. */
function respond(body, res) {
  const last = body.messages.at(-1);
  const toolResults = Array.isArray(last.content) ? last.content.filter((b) => b.type === 'tool_result') : [];
  const lastToolName = (() => {
    const prev = body.messages.at(-2);
    return prev?.role === 'assistant' ? prev.content.find((b) => b.type === 'tool_use')?.name : null;
  })();
  const userText = Array.isArray(last.content) ? last.content.filter((b) => b.type === 'text').map((b) => b.text).join(' ') : String(last.content);
  const tomorrow = new Date(Date.now() + 86400_000).toISOString().slice(0, 10);

  if (!toolResults.length && /ăn gì/.test(userText)) {
    return sse(res, [{ type: 'text', text: 'Tối nay có thể nấu bò hầm, thịt bò trong tủ còn khá nhiều.' }], 'end_turn');
  }
  if (!toolResults.length) {
    return sse(res, [{ type: 'text', text: 'Để mình xem tủ lạnh nhé. ' }, { type: 'tool_use', id: 'toolu_1', name: 'list_fridge_items', input: {} }], 'tool_use');
  }
  if (lastToolName === 'list_fridge_items') {
    return sse(res, [{ type: 'tool_use', id: 'toolu_2', name: 'create_shopping_list', input: { name: 'Đi chợ tối nay', date: tomorrow } }], 'tool_use');
  }
  if (lastToolName === 'create_shopping_list') {
    const actionId = JSON.parse(toolResults[0].content).actionId;
    return sse(res, [{
      type: 'tool_use', id: 'toolu_3', name: 'add_shopping_tasks',
      input: { listId: `$action:${actionId}.listId`, tasks: [{ foodName: 'Cà chua', quantity: 0.5 }, { foodName: 'Hành lá', quantity: 1 }] },
    }], 'tool_use');
  }
  return sse(res, [{ type: 'text', text: 'Mình đã đề xuất tạo danh sách "Đi chợ tối nay" và thêm cà chua, hành lá. Bạn bấm xác nhận nhé!' }], 'end_turn');
}

function startMock() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let raw = '';
      req.on('data', (c) => { raw += c; });
      req.on('end', () => {
        const body = JSON.parse(raw || '{}');
        requests.push({ url: req.url, headers: req.headers, body });
        respond(body, res);
      });
    });
    server.listen(MOCK_PORT, () => resolve(server));
  });
}

// ---------------- Kịch bản kiểm thử ----------------
let passed = 0;
let failed = 0;
const ok = (name, cond, extra = '') => {
  if (cond) { passed += 1; console.log(`  ✓ ${name}`); } else { failed += 1; console.log(`  ✗ ${name} ${extra}`); }
};
async function call(method, path, { token, body, headers = {} } = {}) {
  const res = await fetch(API + path, {
    method,
    headers: { ...(body ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers },
    body: body ? JSON.stringify(body) : undefined,
  });
  if ((res.headers.get('content-type') ?? '').includes('text/event-stream')) return { sse: await res.text() };
  return res.json();
}

async function scenario() {
  const db = new pg.Client({ connectionString: DB });
  await db.connect();
  const sfx = Date.now().toString(36).slice(-5);
  const email = `ai.${sfx}@test.local`;
  await call('POST', '/user', { body: { email, password: 'secret123', name: 'Người dùng AI' } });
  await db.query('UPDATE users SET email_verified_at = now() WHERE lower(email) = $1', [email]);
  const login = await call('POST', '/user/login', { body: { email, password: 'secret123' } });
  const token = login.data.accessToken;
  await call('PUT', '/user', { token, body: { username: `ai${sfx}` } });
  await call('POST', '/user/group', { token });
  for (const [name, cat, unit] of [['Thịt bò', 'Thịt', 'kg'], ['Cà chua', 'Rau củ', 'kg'], ['Hành lá', 'Rau củ', 'bó']]) {
    await call('POST', '/food', { token, body: { name, foodCategoryName: cat, unitName: unit } });
  }
  await call('POST', '/fridge', { token, body: { foodName: 'Thịt bò', quantity: 0.5, useWithin: '2' } });

  console.log('\n== Lượt 1 (JSON): tool đọc tự chạy, tool ghi chờ xác nhận, tham chiếu $action');
  const r1 = await call('POST', '/ai/chat', {
    token,
    body: { message: 'Thiếu gì thì tạo danh sách đi chợ tối nay', clientContext: { screen: 'fridge' } },
  });
  ok('Mã 00410', r1.code === '00410', JSON.stringify(r1).slice(0, 300));
  ok('Đọc tủ lạnh tự thực thi', r1.data?.executedActions?.[0]?.tool === 'list_fridge_items' && r1.data.executedActions[0].resultCode === '00228');
  ok('2 hành động chờ xác nhận', r1.data?.pendingActions?.length === 2);
  const [pList, pTasks] = r1.data.pendingActions;
  ok('Hành động thêm món phụ thuộc hành động tạo danh sách', pTasks.dependsOn === pList.actionId);
  ok('Câu trả lời cuối', /xác nhận/.test(r1.data.message.content));
  ok('Gửi 4 request tới LLM', requests.length === 4, `(${requests.length})`);

  const sys0 = JSON.stringify(requests[0].body.system);
  const tools0 = JSON.stringify(requests[0].body.tools);
  ok('System prompt giữ nguyên giữa các bước', requests.every((r) => JSON.stringify(r.body.system) === sys0));
  ok('Danh sách tool giữ nguyên giữa các bước', requests.every((r) => JSON.stringify(r.body.tools) === tools0));
  ok('Không gửi tham số thinking/temperature', requests.every((r) => r.body.thinking === undefined && r.body.temperature === undefined));
  ok('Gửi effort + compaction + fallback', requests.every((r) => r.body.output_config?.effort && r.body.context_management && r.body.fallbacks === 'default'));
  ok('Header beta có compaction', /compact-2026-01-12/.test(requests[0].headers['anthropic-beta'] ?? ''));
  ok('Khối ngữ cảnh nằm trong tin nhắn người dùng', /Ngữ cảnh hệ thống/.test(requests[0].body.messages[0].content[0].text));

  const conversationId = r1.data.conversationId;
  console.log('\n== Xác nhận hành động');
  const conf = await call('POST', '/ai/action/confirm', { token, body: { actionIds: [pList.actionId, pTasks.actionId] } });
  ok('Mã 00423', conf.code === '00423', JSON.stringify(conf).slice(0, 300));
  const lists = await call('GET', '/shopping/task', { token });
  const list = lists.data.lists.find((l) => l.name === 'Đi chợ tối nay');
  ok('Danh sách được tạo với 2 món (listId đã thay từ $action)', list?.tasks.length === 2);
  const logs = await db.query(`SELECT count(*)::int AS n FROM audit_logs WHERE source = 'ai' AND ai_action_id = ANY($1::bigint[])`, [[pList.actionId, pTasks.actionId]]);
  ok('audit_logs ghi source = ai kèm ai_action_id', logs.rows[0].n === 2);

  console.log('\n== Lượt 2 (SSE): lịch sử chỉ nối thêm');
  const before = requests.length;
  const r2 = await call('POST', '/ai/chat', { token, body: { conversationId, message: 'Vậy tối nay ăn gì?', stream: true } });
  const events = [...r2.sse.matchAll(/event: ([\w.]+)\n/g)].map((m) => m[1]);
  ok('Sự kiện conversation -> message.delta -> message.completed', events[0] === 'conversation' && events.includes('message.delta') && events.at(-1) === 'message.completed', events.join(','));
  const prev = requests[before - 1].body.messages;
  const next = requests[before].body.messages;
  const prefixSame = prev.every((m, i) => JSON.stringify(m) === JSON.stringify(next[i]));
  ok('Request mới giữ nguyên toàn bộ lịch sử cũ (append-only)', prefixSame && next.length > prev.length);
  if (!prefixSame) {
    const i = prev.findIndex((m, k) => JSON.stringify(m) !== JSON.stringify(next[k]));
    console.log(`    khác ở messages[${i}]\n    trước: ${JSON.stringify(prev[i]).slice(0, 500)}\n    sau:   ${JSON.stringify(next[i]).slice(0, 500)}`);
  }
  ok('Kết quả xác nhận được nối vào hội thoại', next.some((m) => m.role === 'user' && JSON.stringify(m.content).includes('Kết quả từ ứng dụng')));

  const detail = await call('GET', `/ai/conversation/${conversationId}`, { token });
  ok('Chi tiết hội thoại ẩn khối ngữ cảnh', detail.code === '00406' && detail.data.messages.every((m) => !m.text.includes('Ngữ cảnh hệ thống')));
  const usage = await call('GET', '/ai/usage', { token });
  ok('Ghi nhận token sử dụng', usage.data?.days?.[0]?.requests === 2 && usage.data.todayUsed > 0);
  await db.end();
  console.log(`\nKết quả: ${passed} đạt, ${failed} lỗi`);
  return failed;
}

const mode = process.argv[2];
if (mode === '--mock') {
  await startMock();
  console.log(`mock LLM tại http://localhost:${MOCK_PORT}`);
} else if (mode === '--all') {
  const mock = await startMock();
  const api = spawn(process.execPath, ['src/server.js'], {
    env: {
      ...process.env, PORT: '3002', DATABASE_URL: DB, AI_API_KEY: 'dummy', AI_BASE_URL: `http://localhost:${MOCK_PORT}`,
      SMTP_HOST: '', UPLOAD_DIR: process.env.UPLOAD_DIR || './uploads-test', EXPIRY_JOB_CRON: '0 0 1 1 *',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let log = '';
  api.stdout.on('data', (d) => { log += d; });
  api.stderr.on('data', (d) => { log += d; });
  for (let i = 0; i < 40; i++) {
    try { if ((await fetch(`${API}/health`)).ok) break; } catch { /* chưa sẵn sàng */ }
    await new Promise((r) => setTimeout(r, 300));
  }
  let code = 1;
  try {
    code = await scenario();
  } catch (err) {
    console.error(err);
  } finally {
    api.kill();
    mock.close();
    if (code) console.log(log.split('\n').filter((l) => /error|lỗi/i.test(l)).slice(-20).join('\n'));
    process.exit(code ? 1 : 0);
  }
} else {
  process.exit(await scenario());
}
