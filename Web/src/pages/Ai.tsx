import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { ApiError } from '../api/client';
import { aiApi } from '../api/endpoints';
import type { AiAction, AiMessage } from '../api/types';
import { Modal, useAction, useConfirm, useLoad, useToast } from '../components/ui';
import { relativeTime } from '../lib/format';
import { useSession } from '../lib/session';

const TOOL_LABELS: Record<string, string> = {
  list_fridge_items: 'Đang xem tủ lạnh', find_expiring_items: 'Đang tìm đồ sắp hết hạn', get_fridge_item: 'Đang xem tủ lạnh',
  list_foods: 'Đang tra danh sách thực phẩm', list_shopping_sessions: 'Đang xem danh sách mua sắm', get_meal_plans: 'Đang xem lịch bữa ăn',
  check_meal_ingredients: 'Đang kiểm tra nguyên liệu', get_recipes: 'Đang tìm công thức', get_recipe_detail: 'Đang đọc công thức',
  suggest_recipes: 'Đang gợi ý món', get_group_members: 'Đang xem thành viên nhóm', read_attachment: 'Đang xem ảnh',
};

interface Live {
  text: string;
  tools: { id: number; label: string; done: boolean; ok: boolean }[];
}

/** Trợ lý AI: hội thoại (stream SSE), thẻ xác nhận hành động, cài đặt, gợi ý chủ động. */
export function AiPage() {
  const params = useParams();
  const convId = params.id ? Number(params.id) : null;
  const nav = useNavigate();
  const s = useSession();
  const toast = useToast();
  const confirm = useConfirm();
  const { run, busy } = useAction();
  const [showSettings, setShowSettings] = useState(false);

  const settings = useLoad(() => aiApi.settings(), []);
  const convs = useLoad(() => aiApi.conversations(), []);
  const suggestions = useLoad(() => (s.isLeader ? aiApi.suggestions() : Promise.resolve([])), [s.isLeader]);
  const detail = useLoad(() => (convId ? aiApi.conversation(convId) : Promise.resolve(null)), [convId]);

  const [messages, setMessages] = useState<AiMessage[]>([]);
  const [actions, setActions] = useState<AiAction[]>([]);
  const [live, setLive] = useState<Live | null>(null);
  const [input, setInput] = useState('');
  const [image, setImage] = useState<File | null>(null);
  const abort = useRef<AbortController | null>(null);
  const logRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setMessages(detail.data?.messages.filter((m) => m.role !== 'tool') ?? []);
    setActions(detail.data?.actions ?? []);
  }, [detail.data]);
  useEffect(() => {
    logRef.current?.scrollTo({ top: logRef.current.scrollHeight });
  }, [messages, live]);

  const pending = actions.filter((a) => a.status === 'proposed' && (!a.expiresAt || new Date(a.expiresAt) > new Date()));

  async function send() {
    const text = input.trim();
    if (!text || live) return;
    setInput('');
    const img = image;
    setImage(null);
    setMessages((m) => [...m, { id: -Date.now(), role: 'user', text, attachmentIds: img ? [0] : [] }]);
    setLive({ text: '', tools: [] });
    abort.current = new AbortController();
    let target = convId;
    try {
      const attachmentIds = img ? [await aiApi.upload(img)] : [];
      await aiApi.chatStream({ conversationId: convId, message: text, attachmentIds, screen: 'web_ai' }, (ev, d) => {
        if (ev === 'conversation') target = d.conversationId;
        else if (ev === 'message.delta') setLive((l) => (l ? { ...l, text: l.text + d.text } : l));
        else if (ev === 'tool.started') setLive((l) => (l ? { ...l, tools: [...l.tools, { id: d.actionId, label: TOOL_LABELS[d.tool] ?? d.summary, done: false, ok: true }] } : l));
        else if (ev === 'tool.finished') setLive((l) => (l ? { ...l, tools: l.tools.map((t) => (t.id === d.actionId ? { ...t, done: true, ok: d.status === 'executed' } : t)) } : l));
        else if (ev === 'error') toast({ text: d.message, error: true });
      }, abort.current.signal);
    } catch (e) {
      if ((e as Error).name !== 'AbortError') {
        toast({ text: (e as ApiError).message, error: true });
        setInput(text);
      }
    } finally {
      setLive(null);
      abort.current = null;
      convs.reload();
      if (target && target !== convId) nav(`/ai/${target}`);
      else detail.reload();
    }
  }

  async function decide(ok: boolean) {
    const ids = pending.map((a) => a.actionId);
    if (ok) {
      const r = await run(() => aiApi.confirm(ids));
      if (r) {
        const failed = r.data.results.filter((x) => x.status !== 'executed');
        toast(failed.length ? { text: `Một số hành động chưa thực hiện được:\n${failed.map((f) => `#${f.actionId}: ${f.message}`).join('\n')}`, error: true } : { text: `Đã thực hiện ${ids.length} hành động` });
      }
    } else {
      await run(() => aiApi.reject(ids), 'Đã từ chối');
    }
    detail.reload();
  }

  const unavailable = settings.data && (!settings.data.aiAvailable || !settings.data.settings.enabled);

  return (
    <div style={{ display: 'flex', gap: 18 }}>
      <aside style={{ width: 240, flexShrink: 0 }} className="hide-narrow">
        <div className="row" style={{ marginBottom: 10 }}>
          <Link to="/ai" className="btn" style={{ flex: 1, justifyContent: 'center' }}>+ Hội thoại mới</Link>
          <button className="ghost" title="Cài đặt" onClick={() => setShowSettings(true)}>⚙️</button>
        </div>
        {(suggestions.data?.length ?? 0) > 0 && (
          <div className="card" style={{ marginBottom: 10, background: 'var(--warn-soft)' }}>
            <b>💡 Gợi ý</b>
            {suggestions.data!.map((sg) => (
              <div key={sg.id} style={{ marginTop: 8, fontSize: 13 }}>
                {sg.title}
                <div className="row">
                  <button className="small" onClick={async () => { const id = await run(() => aiApi.accept(sg.id)); if (id) { suggestions.reload(); nav(`/ai/${id}`); } }}>Xem</button>
                  <button className="small ghost" onClick={async () => { await run(() => aiApi.dismiss(sg.id)); suggestions.reload(); }}>Bỏ qua</button>
                </div>
              </div>
            ))}
          </div>
        )}
        {s.isLeader && <button className="link" onClick={async () => { await run(() => aiApi.refreshSuggestions(), 'Đã cập nhật gợi ý'); suggestions.reload(); }}>↻ Tìm gợi ý mới</button>}
        <div className="list" style={{ marginTop: 8 }}>
          {convs.data?.map((c) => (
            <div key={c.id} className={`item click`} style={{ background: c.id === convId ? 'var(--primary-soft)' : undefined }} onClick={() => nav(`/ai/${c.id}`)}>
              <div className="grow">
                <div style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.title}</div>
                <div className="sub">{relativeTime(c.updatedAt)}</div>
              </div>
              <button className="icon" title="Xóa" onClick={async (e) => {
                e.stopPropagation();
                if (await confirm(`Xóa cuộc hội thoại "${c.title}"?`)) {
                  await run(() => aiApi.removeConversation(c.id));
                  convs.reload();
                  if (c.id === convId) nav('/ai');
                }
              }}>🗑</button>
            </div>
          ))}
          {!convs.data?.length && <div className="item muted">Chưa có hội thoại</div>}
        </div>
      </aside>

      <section className="chat" style={{ flex: 1, minWidth: 0 }}>
        <div className="page-head" style={{ marginBottom: 6 }}>
          <h1>🤖 {detail.data?.conversation.title ?? 'Trợ lý AI'}</h1>
        </div>
        {unavailable && (
          <div className="pending">
            {!settings.data!.aiAvailable ? 'Máy chủ chưa cấu hình khóa API cho trợ lý AI (AI_API_KEY).' : 'Trợ lý AI đang tắt trong cài đặt của bạn.'}
          </div>
        )}
        <div className="chat-log" ref={logRef}>
          {!messages.length && !live && (
            <div className="center muted">
              Thử hỏi: “Tủ lạnh còn gì sắp hết hạn?”, “Tối nay nấu gì? Thiếu gì thì tạo danh sách đi chợ.”, hoặc gửi ảnh hóa đơn để nhập tủ lạnh.
            </div>
          )}
          {messages.map((m) =>
            m.text ? (
              <div key={m.id} className={`bubble ${m.role === 'user' ? 'user' : 'assistant'}`}>
                {m.attachmentIds?.length ? <div style={{ fontSize: 12, opacity: 0.8 }}>[ảnh đính kèm]</div> : null}
                {m.text}
              </div>
            ) : null,
          )}
          {live && (
            <div>
              {live.tools.map((t) => (
                <div key={t.id} className="tool-line">{t.done ? (t.ok ? '✓' : '✗') : <span className="spinner" style={{ width: 10, height: 10 }} />} {t.label}…</div>
              ))}
              <div className="bubble assistant">{live.text || <span className="muted"><span className="spinner" /> Trợ lý đang suy nghĩ…</span>}</div>
            </div>
          )}
          {pending.length > 0 && !live && (
            <div className="pending">
              <b>Hành động chờ bạn xác nhận</b>
              <ul style={{ margin: '8px 0', paddingLeft: 20 }}>
                {pending.map((a) => (
                  <li key={a.actionId}>
                    {a.riskLevel === 'destructive' ? '🗑️ ' : '✏️ '}{a.summary}{a.dependsOn ? <span className="muted"> (sau #{a.dependsOn})</span> : null}
                  </li>
                ))}
              </ul>
              <div className="row end" style={{ marginTop: 0 }}>
                <button className="ghost" disabled={busy} onClick={() => decide(false)}>Từ chối</button>
                <button disabled={busy} onClick={() => decide(true)}>Đồng ý tất cả ({pending.length})</button>
              </div>
            </div>
          )}
        </div>
        {image && <div className="muted" style={{ fontSize: 13 }}>📎 {image.name} <button className="link" onClick={() => setImage(null)}>bỏ</button></div>}
        <div className="chat-input">
          <label className="btn" style={{ background: 'transparent', color: '#000', border: '1px solid var(--line)' }} title="Gửi ảnh hóa đơn / tủ lạnh">
            📷<input type="file" accept="image/jpeg,image/png,image/webp" style={{ display: 'none' }} onChange={(e) => setImage(e.target.files?.[0] ?? null)} />
          </label>
          <textarea
            rows={2}
            maxLength={4000}
            placeholder="Nhắn cho trợ lý… (Enter để gửi, Shift+Enter xuống dòng)"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                send();
              }
            }}
          />
          {live ? (
            <button className="danger-btn" onClick={() => { abort.current?.abort(); if (convId) aiApi.cancel(convId).catch(() => {}); }}>Dừng</button>
          ) : (
            <button onClick={send} disabled={!input.trim()}>Gửi</button>
          )}
        </div>
      </section>

      {showSettings && settings.data && (
        <Modal title="Cài đặt trợ lý AI" onClose={() => setShowSettings(false)}>
          <div className="stack">
            <label className="row"><input type="checkbox" style={{ width: 18 }} checked={settings.data.settings.enabled}
              onChange={async (e) => { await run(() => aiApi.updateSettings({ enabled: e.target.checked })); settings.reload(); }} /> Bật trợ lý AI</label>
            <label className="row"><input type="checkbox" style={{ width: 18 }} checked={settings.data.settings.autoExecuteLevel === 'write'}
              onChange={async (e) => { await run(() => aiApi.updateSettings({ autoExecuteLevel: e.target.checked ? 'write' : 'read' })); settings.reload(); }} /> Tự thực hiện thao tác tạo/sửa</label>
            <p className="muted" style={{ fontSize: 13 }}>Tắt: mọi thao tác tạo/sửa cần bạn bấm xác nhận. Thao tác xóa luôn cần xác nhận. Hành động chờ quá 15 phút sẽ hết hạn.</p>
            <p>Hạn mức mỗi ngày: <b>{settings.data.settings.dailyTokenLimit.toLocaleString('vi-VN')}</b> token</p>
          </div>
        </Modal>
      )}
    </div>
  );
}
