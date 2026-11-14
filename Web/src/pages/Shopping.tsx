import { useMemo, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { groupApi, shoppingApi } from '../api/endpoints';
import type { Food, Location, ShoppingList, ShoppingTask } from '../api/types';
import { LOCATIONS } from '../api/types';
import { Async, Field, FoodPicker, Modal, NeedGroup, Pill, useAction, useConfirm, useLoad, useToast } from '../components/ui';
import { addDays, fmtDate, isoDate, newKey, parseQty, qtyUnit, today } from '../lib/format';
import { useSession } from '../lib/session';

/** UC03 - danh sách mua sắm của nhóm. */
export function ShoppingPage() {
  const s = useSession();
  const nav = useNavigate();
  const [done, setDone] = useState(false);
  const [mine, setMine] = useState(false);
  const [creating, setCreating] = useState(false);
  const { data, loading, error, reload } = useLoad(() => shoppingApi.lists({ status: done ? 'done' : 'open', assignedToMe: mine }), [done, mine]);
  if (!s.hasGroup) return <NeedGroup />;
  return (
    <>
      <div className="page-head">
        <h1>Danh sách mua sắm</h1>
        {s.isLeader && <button onClick={() => setCreating(true)}>+ Tạo danh sách</button>}
      </div>
      <div className="row" style={{ marginBottom: 12 }}>
        <div className="seg">
          <button className={!done ? 'on' : ''} onClick={() => setDone(false)}>Đang mở</button>
          <button className={done ? 'on' : ''} onClick={() => setDone(true)}>Đã xong</button>
        </div>
        <button className={`chip ${mine ? 'on' : ''}`} onClick={() => setMine(!mine)}>Giao cho tôi</button>
      </div>
      <Async loading={loading} error={error} empty={!data?.lists.length} onRetry={reload}
        emptyText={s.isLeader ? 'Chưa có danh sách. Bấm "Tạo danh sách".' : 'Chưa có danh sách nào — trưởng nhóm sẽ tạo và phân công.'}>
        <div className="list">
          {data?.lists.map((l) => (
            <Link key={l.id} to={`/shopping/${l.id}`} className="item click" style={{ color: '#000' }}>
              <div className="grow">
                <div className="title">{l.name} {l.assignedTo?.id === s.user?.id && <Pill tone="warn">Giao cho tôi</Pill>}</div>
                <div className="sub">Ngày {fmtDate(l.date)} · {l.assignedTo ? `Người mua: ${l.assignedTo.name}` : 'Chưa giao'}</div>
                <div className="progress" style={{ marginTop: 6, maxWidth: 320 }}>
                  <div style={{ width: `${l.progress.total ? (l.progress.bought / l.progress.total) * 100 : 0}%` }} />
                </div>
              </div>
              <span className="num">{l.progress.bought}/{l.progress.total}</span>
            </Link>
          ))}
        </div>
      </Async>
      {creating && <ListForm onClose={() => setCreating(false)} onSaved={(id) => nav(`/shopping/${id}?add=1`)} />}
    </>
  );
}

/** Tạo/sửa danh sách (trưởng nhóm). Người được giao chỉ chọn trong thành viên cùng nhóm. */
function ListForm({ list, onClose, onSaved }: { list?: ShoppingList; onClose: () => void; onSaved: (id: number) => void }) {
  const { run, busy } = useAction();
  const members = useLoad(() => groupApi.get().then((g) => g.group.members), []);
  const [f, setF] = useState({ name: list?.name ?? 'Đi chợ', date: list?.date ?? isoDate(today()), assignee: list?.assignedTo?.username ?? '', note: list?.note ?? '' });
  const [err, setErr] = useState('');
  async function save() {
    if (!f.name.trim()) return setErr('Tên danh sách không được để trống');
    if (list) {
      const body: Record<string, unknown> = { listId: list.id };
      if (f.name.trim() !== list.name) body.newName = f.name.trim();
      if (f.date !== list.date) body.newDate = f.date;
      if (f.assignee !== (list.assignedTo?.username ?? '')) body.newAssignToUsername = f.assignee;
      if (f.note !== (list.note ?? '')) body.newNote = f.note;
      if (Object.keys(body).length === 1) return onClose();
      if (await run(() => shoppingApi.update(body), 'Đã cập nhật danh sách')) onSaved(list.id);
    } else {
      const r = await run(() => shoppingApi.create({ name: f.name.trim(), date: f.date, assignToUsername: f.assignee || undefined, note: f.note || undefined }), 'Đã tạo danh sách. Hãy thêm món cần mua.');
      if (r) onSaved(r.data.listId);
    }
  }
  return (
    <Modal title={list ? 'Sửa danh sách' : 'Tạo danh sách mua sắm'} onClose={onClose}>
      <div className="stack">
        <Field label="Tên danh sách" error={err}><input value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} autoFocus /></Field>
        <Field label="Ngày đi chợ"><input type="date" value={f.date} onChange={(e) => setF({ ...f, date: e.target.value })} /></Field>
        <Field label="Giao cho" hint="Chỉ chọn được thành viên cùng nhóm đã đặt tên người dùng">
          <select value={f.assignee} onChange={(e) => setF({ ...f, assignee: e.target.value })}>
            <option value="">Chưa giao</option>
            {members.data?.filter((m) => m.username).map((m) => <option key={m.id} value={m.username!}>{m.name} (@{m.username})</option>)}
          </select>
        </Field>
        <Field label="Ghi chú"><textarea rows={2} value={f.note} onChange={(e) => setF({ ...f, note: e.target.value })} /></Field>
      </div>
      <div className="row end">
        <button className="ghost" onClick={onClose}>Hủy</button>
        <button onClick={save} disabled={busy}>{list ? 'Lưu' : 'Tạo và thêm món'}</button>
      </div>
    </Modal>
  );
}

export function ShoppingDetail() {
  const id = Number(useParams().id);
  const s = useSession();
  const nav = useNavigate();
  const confirm = useConfirm();
  const { run } = useAction();
  const [modal, setModal] = useState<'add' | 'edit' | 'buy' | null>(new URLSearchParams(location.search).get('add') ? 'add' : null);
  const { data: l, loading, error, reload } = useLoad(() => shoppingApi.get(id), [id]);
  const pending = l?.tasks.filter((t) => t.status === 'pending') ?? [];
  const canBuy = !!l && (s.isLeader || l.assignedTo?.id === s.user?.id) && pending.length > 0;

  async function editQty(t: ShoppingTask) {
    const v = prompt(`Số lượng ${t.food.name} (${t.food.unit.name})`, String(t.quantity));
    if (v === null) return;
    const q = parseQty(v);
    if (!(q > 0)) return alert('Số lượng phải là số lớn hơn 0');
    await run(() => shoppingApi.updateTask({ taskId: t.id, newQuantity: q }), 'Đã cập nhật');
    reload();
  }

  return (
    <Async loading={loading} error={error} empty={!l} onRetry={reload}>
      {l && (
        <>
          <div className="page-head">
            <h1>{l.name}</h1>
            {canBuy && <button onClick={() => setModal('buy')}>🛍️ Xác nhận đã mua ({pending.length})</button>}
            {s.isLeader && (
              <>
                <button className="ghost" onClick={() => setModal('add')}>+ Thêm món</button>
                <button className="ghost" onClick={() => setModal('edit')}>Sửa</button>
                <button className="ghost" onClick={async () => {
                  if (await confirm(`Xóa "${l.name}" và toàn bộ món trong danh sách?`)) {
                    if (await run(() => shoppingApi.remove(l.id), 'Đã xóa danh sách')) nav('/shopping');
                  }
                }}>Xóa</button>
              </>
            )}
          </div>
          <p className="muted">
            Ngày đi chợ {fmtDate(l.date)} · {l.assignedTo ? `Người mua: ${l.assignedTo.name} (@${l.assignedTo.username})` : 'Chưa giao cho ai'}
            {l.note && <><br />📝 {l.note}</>}
          </p>
          <h2>Cần mua ({pending.length})</h2>
          <div className="list">
            {pending.length === 0 && <div className="item muted">Không còn món nào cần mua.</div>}
            {pending.map((t) => (
              <div key={t.id} className="item">
                <span>⬜</span>
                <div className="grow"><div className="title">{t.food.name}</div><div className="sub">{t.food.category.name}</div></div>
                <span className="num">{qtyUnit(t.quantity, t.food.unit.name)}</span>
                {s.isLeader && (
                  <>
                    <button className="small ghost" onClick={() => editQty(t)}>Sửa SL</button>
                    <button className="small ghost" onClick={async () => {
                      if (await confirm(`Xóa ${t.food.name} khỏi danh sách?`)) { await run(() => shoppingApi.removeTask(t.id), 'Đã xóa'); reload(); }
                    }}>Xóa</button>
                  </>
                )}
              </div>
            ))}
          </div>
          {l.progress.bought > 0 && (
            <>
              <h2>Đã mua ({l.progress.bought})</h2>
              <div className="list">
                {l.tasks.filter((t) => t.status === 'bought').map((t) => (
                  <div key={t.id} className="item">
                    <span>✅</span>
                    <div className="grow"><div className="title" style={{ textDecoration: 'line-through' }}>{t.food.name}</div>
                      <div className="sub">{t.boughtBy?.name}{t.boughtAt ? ` · ${fmtDate(t.boughtAt)}` : ''}</div></div>
                    <span className="num">{qtyUnit(t.boughtQuantity ?? t.quantity, t.food.unit.name)}</span>
                  </div>
                ))}
              </div>
            </>
          )}
          {modal === 'add' && <AddTasks listId={l.id} onClose={() => { setModal(null); reload(); }} />}
          {modal === 'edit' && <ListForm list={l} onClose={() => setModal(null)} onSaved={() => { setModal(null); reload(); }} />}
          {modal === 'buy' && <Purchase list={l} onClose={(ok) => { setModal(null); if (ok) reload(); }} />}
        </>
      )}
    </Async>
  );
}

/** Thêm nhiều món một lần; mục lỗi (không tồn tại, trùng) được giữ lại để sửa (UC03 - 5a). */
function AddTasks({ listId, onClose }: { listId: number; onClose: () => void }) {
  const toast = useToast();
  const [rows, setRows] = useState<{ key: number; food: Food | null; qty: string }[]>([{ key: 1, food: null, qty: '1' }]);
  const [busy, setBusy] = useState(false);
  const upd = (k: number, patch: Partial<{ food: Food | null; qty: string }>) => setRows(rows.map((r) => (r.key === k ? { ...r, ...patch } : r)));
  async function save() {
    const valid = rows.filter((r) => r.food && parseQty(r.qty) > 0);
    if (!valid.length) return toast({ text: 'Chọn thực phẩm và nhập số lượng > 0 cho ít nhất một dòng', error: true });
    setBusy(true);
    try {
      const r = await shoppingApi.addTasks(listId, valid.map((v) => ({ foodName: v.food!.name, quantity: parseQty(v.qty) })));
      if (!r.data.failed.length) {
        toast({ text: `Đã thêm ${r.data.created.length} món` });
        return onClose();
      }
      const failed = new Set(r.data.failed.map((f) => f.foodName.toLowerCase()));
      setRows(rows.filter((x) => !x.food || failed.has(x.food.name.toLowerCase())));
      toast({ text: `Đã thêm ${r.data.created.length} món. Chưa thêm được:\n${r.data.failed.map((f) => `• ${f.foodName}: ${f.message}`).join('\n')}`, error: true });
    } catch (e) {
      const err = e as { message: string; data?: { failed?: { foodName: string; message: string }[] } };
      toast({ text: err.data?.failed ? err.data.failed.map((f) => `${f.foodName}: ${f.message}`).join('\n') : err.message, error: true });
    } finally {
      setBusy(false);
    }
  }
  return (
    <Modal title="Thêm món cần mua" onClose={onClose} wide>
      <div className="stack">
        {rows.map((r) => (
          <div key={r.key} className="row" style={{ flexWrap: 'nowrap' }}>
            <div style={{ flex: 3 }}><FoodPicker value={r.food} onChange={(f) => upd(r.key, { food: f })} /></div>
            <input style={{ flex: 1 }} className="num-input" value={r.qty} onChange={(e) => upd(r.key, { qty: e.target.value })} placeholder="SL" />
            <span className="muted" style={{ width: 40 }}>{r.food?.unit.name}</span>
            <button className="icon" disabled={rows.length === 1} onClick={() => setRows(rows.filter((x) => x.key !== r.key))}>✕</button>
          </div>
        ))}
        <button className="link" onClick={() => setRows([...rows, { key: Date.now(), food: null, qty: '1' }])}>+ Thêm dòng</button>
      </div>
      <div className="row end">
        <button className="ghost" onClick={onClose}>Đóng</button>
        <button onClick={save} disabled={busy}>{busy && <span className="spinner" />} Thêm vào danh sách</button>
      </div>
    </Modal>
  );
}

/**
 * UC04 - Xác nhận đã mua: số lượng thực mua, hạn dùng, vị trí; backend xử lý trong MỘT giao dịch.
 * Khóa chống lặp giữ nguyên khi bấm "Thử lại" sau lỗi mạng, đổi nội dung thì sinh khóa mới (NFR10).
 */
function Purchase({ list, onClose }: { list: ShoppingList; onClose: (ok: boolean) => void }) {
  const toast = useToast();
  const defaultExpiry = isoDate(addDays(today(), 3));
  const pending = useMemo(() => list.tasks.filter((t) => t.status === 'pending'), [list]);
  const [items, setItems] = useState(() =>
    Object.fromEntries(pending.map((t) => [t.id, { on: true, qty: String(t.quantity), toFridge: true, useWithin: defaultExpiry, location: 'cool' as Location }])),
  );
  const key = useRef(newKey());
  const [busy, setBusy] = useState(false);
  const upd = (id: number, patch: Partial<(typeof items)[number]>) => {
    key.current = newKey();
    setItems({ ...items, [id]: { ...items[id], ...patch } });
  };
  async function submit() {
    const chosen = pending.filter((t) => items[t.id].on);
    if (!chosen.length) return toast({ text: 'Hãy chọn ít nhất một món đã mua', error: true });
    for (const t of chosen) {
      if (!(parseQty(items[t.id].qty) > 0)) return toast({ text: `Số lượng thực mua của ${t.food.name} phải lớn hơn 0`, error: true });
    }
    setBusy(true);
    try {
      await shoppingApi.purchase(
        list.id,
        chosen.map((t) => {
          const d = items[t.id];
          return { taskId: t.id, boughtQuantity: parseQty(d.qty), addToFridge: d.toFridge, ...(d.toFridge ? { useWithin: d.useWithin, location: d.location } : {}) };
        }),
        key.current,
      );
      toast({ text: `Đã xác nhận mua ${chosen.length} món, tủ lạnh đã được cập nhật` });
      onClose(true);
    } catch (e) {
      const err = e as { message: string; network?: boolean };
      toast({ text: err.message, error: true, retry: err.network ? submit : undefined });
    } finally {
      setBusy(false);
    }
  }
  return (
    <Modal title="Xác nhận đã mua" onClose={() => onClose(false)} wide>
      <p className="muted">Chọn món đã mua, sửa số lượng thực mua và hạn dùng. Món đưa vào tủ lạnh sẽ cộng dồn vào mục có sẵn.</p>
      <table>
        <thead>
          <tr><th></th><th>Món</th><th className="n">Thực mua</th><th>Vào tủ lạnh</th><th>Hạn dùng</th><th>Vị trí</th></tr>
        </thead>
        <tbody>
          {pending.map((t) => {
            const d = items[t.id];
            return (
              <tr key={t.id} style={{ opacity: d.on ? 1 : 0.5 }}>
                <td><input type="checkbox" checked={d.on} onChange={(e) => upd(t.id, { on: e.target.checked })} style={{ width: 18 }} /></td>
                <td>{t.food.name}<div className="muted" style={{ fontSize: 12 }}>cần {qtyUnit(t.quantity, t.food.unit.name)}</div></td>
                <td className="n"><input className="num-input" style={{ width: 80 }} value={d.qty} onChange={(e) => upd(t.id, { qty: e.target.value })} disabled={!d.on} /> {t.food.unit.name}</td>
                <td><input type="checkbox" checked={d.toFridge} onChange={(e) => upd(t.id, { toFridge: e.target.checked })} disabled={!d.on} style={{ width: 18 }} /></td>
                <td><input type="date" value={d.useWithin} onChange={(e) => upd(t.id, { useWithin: e.target.value })} disabled={!d.on || !d.toFridge} /></td>
                <td>
                  <select value={d.location} onChange={(e) => upd(t.id, { location: e.target.value as Location })} disabled={!d.on || !d.toFridge}>
                    {Object.entries(LOCATIONS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                  </select>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
      <div className="row end">
        <button className="ghost" onClick={() => onClose(false)}>Hủy</button>
        <button onClick={submit} disabled={busy}>{busy && <span className="spinner" />} Xác nhận</button>
      </div>
    </Modal>
  );
}
