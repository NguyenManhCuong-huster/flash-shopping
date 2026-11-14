import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { ApiError } from '../api/client';
import { fridgeApi } from '../api/endpoints';
import type { Food, FridgeItem, Location } from '../api/types';
import { LOCATIONS } from '../api/types';
import { Async, Field, FoodPicker, Img, Modal, NeedGroup, Pill, toneOf, useAction, useConfirm, useLoad, useToast } from '../components/ui';
import { addDays, fmtDate, fmtDateTime, fmtQty, isoDate, parseQty, qtyUnit, statusLabel, today } from '../lib/format';
import { useSession } from '../lib/session';

/** UC05 - Quản lý tủ lạnh. */
export function FridgePage() {
  const s = useSession();
  const [q, setQ] = useState('');
  const [query, setQuery] = useState('');
  const [location, setLocation] = useState<Location | ''>('');
  const [expiring, setExpiring] = useState(false);
  const [adding, setAdding] = useState(false);
  useEffect(() => {
    const t = setTimeout(() => setQuery(q), 350);
    return () => clearTimeout(t);
  }, [q]);
  const { data, loading, error, reload } = useLoad(() => fridgeApi.list({ q: query, location, expiringDays: expiring ? 3 : undefined }), [query, location, expiring]);
  if (!s.hasGroup) return <NeedGroup />;
  const sum = data?.summary;
  return (
    <>
      <div className="page-head">
        <h1>Tủ lạnh</h1>
        <input style={{ maxWidth: 260 }} placeholder="🔍 Tìm trong tủ lạnh" value={q} onChange={(e) => setQ(e.target.value)} />
        <button onClick={() => setAdding(true)}>+ Thêm vào tủ</button>
      </div>
      <div className="chips">
        <button className={`chip ${location === '' ? 'on' : ''}`} onClick={() => setLocation('')}>Tất cả ({sum?.total ?? 0})</button>
        {(Object.keys(LOCATIONS) as Location[]).map((l) => (
          <button key={l} className={`chip ${location === l ? 'on' : ''}`} onClick={() => setLocation(l)}>{LOCATIONS[l]}</button>
        ))}
        <button className={`chip ${expiring ? 'on' : ''}`} onClick={() => setExpiring(!expiring)}>⏰ Sắp hết hạn ({(sum?.expiring ?? 0) + (sum?.expired ?? 0)})</button>
      </div>
      <Async loading={loading} error={error} empty={!data?.items.length} onRetry={reload} emptyText="Tủ lạnh trống. Thêm thực phẩm hoặc xác nhận mua từ danh sách đi chợ.">
        <div className="list">
          {data?.items.map((i) => (
            <Link key={i.id} to={`/fridge/${i.id}`} className="item click" style={{ color: '#000', borderLeft: i.status === 'fresh' ? undefined : `4px solid var(--${i.status === 'expired' ? 'bad' : 'warn'})` }}>
              <Img src={i.food.imageUrl} />
              <div className="grow">
                <div className="title">{i.food.name}</div>
                <div className="sub">{LOCATIONS[i.location]} · HSD {fmtDate(i.useWithin)}{i.note ? ` · ${i.note}` : ''}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div className="num">{qtyUnit(i.quantity, i.food.unit.name)}</div>
                <Pill tone={toneOf(i.status)}>{statusLabel(i.status, i.daysLeft)}</Pill>
              </div>
            </Link>
          ))}
        </div>
      </Async>
      {adding && <FridgeForm onClose={(ok) => { setAdding(false); if (ok) reload(); }} />}
    </>
  );
}

function FridgeForm({ item, onClose }: { item?: FridgeItem; onClose: (ok: boolean) => void }) {
  const toast = useToast();
  const [food, setFood] = useState<Food | null>(item?.food ?? null);
  const [f, setF] = useState({
    qty: item ? String(item.quantity) : '',
    expiry: item ? isoDate(new Date(item.useWithin)) : isoDate(addDays(today(), 3)),
    location: (item?.location ?? 'cool') as Location,
    note: item?.note ?? '',
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  async function save() {
    const e: Record<string, string> = {};
    if (!food) e.food = 'Hãy chọn thực phẩm';
    if (!(parseQty(f.qty) > 0)) e.qty = 'Số lượng phải là số lớn hơn 0, ví dụ 1,5';
    if (!f.expiry) e.expiry = 'Hãy chọn hạn sử dụng';
    setErrors(e);
    if (Object.keys(e).length) return;
    setBusy(true);
    try {
      if (item) {
        const body: Record<string, unknown> = { itemId: item.id, version: item.version };
        if (parseQty(f.qty) !== item.quantity) body.newQuantity = parseQty(f.qty);
        if (f.expiry !== isoDate(new Date(item.useWithin))) body.newUseWithin = f.expiry;
        if (f.location !== item.location) body.newLocation = f.location;
        if (f.note !== (item.note ?? '')) body.newNote = f.note;
        if (Object.keys(body).length === 2) return onClose(false);
        await fridgeApi.update(body);
        toast({ text: 'Đã cập nhật' });
      } else {
        await fridgeApi.add({ foodName: food!.name, quantity: parseQty(f.qty), useWithin: f.expiry, location: f.location, note: f.note || undefined });
        toast({ text: `Đã thêm ${food!.name} vào tủ lạnh` });
      }
      onClose(true);
    } catch (err) {
      const ae = err as ApiError;
      toast({ text: ae.code === '00199' ? `${ae.message} Hãy mở mục đó và sửa số lượng.` : ae.message, error: true, retry: ae.network ? save : undefined });
    } finally {
      setBusy(false);
    }
  }
  return (
    <Modal title={item ? 'Sửa mục tủ lạnh' : 'Thêm vào tủ lạnh'} onClose={() => onClose(false)}>
      <div className="stack">
        <Field label="Thực phẩm" error={errors.food}>
          {item ? <input value={item.food.name} disabled /> : <FoodPicker value={food} onChange={setFood} />}
        </Field>
        <Field label={`Số lượng${food ? ` (${food.unit.name})` : ''}`} error={errors.qty}>
          <input className="num-input" value={f.qty} onChange={(e) => setF({ ...f, qty: e.target.value })} />
        </Field>
        <Field label="Hạn sử dụng" error={errors.expiry}><input type="date" value={f.expiry} onChange={(e) => setF({ ...f, expiry: e.target.value })} /></Field>
        <Field label="Vị trí">
          <div className="seg">
            {(Object.keys(LOCATIONS) as Location[]).map((l) => (
              <button key={l} type="button" className={f.location === l ? 'on' : ''} onClick={() => setF({ ...f, location: l })}>{LOCATIONS[l]}</button>
            ))}
          </div>
        </Field>
        <Field label="Ghi chú"><input value={f.note} maxLength={500} onChange={(e) => setF({ ...f, note: e.target.value })} /></Field>
      </div>
      <div className="row end">
        <button className="ghost" onClick={() => onClose(false)}>Hủy</button>
        <button onClick={save} disabled={busy}>{busy && <span className="spinner" />} Lưu</button>
      </div>
    </Modal>
  );
}

/** Chi tiết mục tủ lạnh; cũng là đích mở từ thông báo nhắc hạn (UC06 bước 6). */
export function FridgeItemPage() {
  const id = Number(useParams().id);
  const nav = useNavigate();
  const confirm = useConfirm();
  const toast = useToast();
  const { run } = useAction();
  const { data: item, loading, error, reload } = useLoad(() => fridgeApi.item(id), [id]);
  const [mode, setMode] = useState<'edit' | 'consume' | 'discard' | null>(null);
  const [qty, setQty] = useState('');
  const [note, setNote] = useState('');

  async function consume() {
    if (!item) return;
    const q = parseQty(qty);
    if (!(q > 0)) return toast({ text: 'Lượng phải là số lớn hơn 0', error: true });
    if (q > item.quantity) return toast({ text: `Không được vượt quá lượng còn lại (${fmtQty(item.quantity)})`, error: true });
    try {
      const r = await fridgeApi.consume({ itemId: item.id, quantity: q, type: mode === 'discard' ? 'discard' : 'consume', version: item.version, note: note || undefined });
      setMode(null);
      if (r.data.depleted) {
        toast({ text: `Đã dùng hết ${item.food.name}, mục đã được xóa khỏi tủ lạnh.` });
        nav('/fridge');
      } else {
        toast({ text: 'Đã ghi nhận' });
        reload();
      }
    } catch (e) {
      const err = e as ApiError;
      toast({ text: err.message, error: true, retry: err.network ? consume : undefined });
      // UC05 - 4b: người khác vừa cập nhật => tải lại thay vì ghi đè
      if (err.code === '00523') {
        setMode(null);
        reload();
      }
    }
  }

  return (
    <Async loading={loading} error={error} empty={!item} onRetry={reload} emptyText="Mục tủ lạnh không tồn tại hoặc đã được dùng hết.">
      {item && (
        <>
          <div className="page-head">
            <Img src={item.food.imageUrl} size={64} />
            <div style={{ flex: 1 }}>
              <h1>{item.food.name}</h1>
              <span className="muted">{item.food.category.name}</span> <Pill tone={toneOf(item.status)}>{statusLabel(item.status, item.daysLeft)}</Pill>
            </div>
            <button className="ghost" onClick={() => setMode('edit')}>Sửa</button>
            <button className="ghost" onClick={async () => {
              if (await confirm(`Xóa ${item.food.name} khỏi tủ lạnh? (Không tính là tiêu thụ)`)) {
                if (await run(() => fridgeApi.remove(item.id), 'Đã xóa')) nav('/fridge');
              }
            }}>Xóa</button>
          </div>
          <div className="card" style={{ maxWidth: 520 }}>
            <table>
              <tbody>
                <tr><td className="muted">Số lượng</td><td className="n"><b>{qtyUnit(item.quantity, item.food.unit.name)}</b></td></tr>
                <tr><td className="muted">Hạn sử dụng</td><td className="n">{fmtDateTime(item.useWithin)}</td></tr>
                <tr><td className="muted">Vị trí</td><td className="n">{LOCATIONS[item.location]}</td></tr>
                {item.note && <tr><td className="muted">Ghi chú</td><td className="n">{item.note}</td></tr>}
              </tbody>
            </table>
            <div className="row" style={{ marginTop: 14 }}>
              <button onClick={() => { setQty(String(item.quantity)); setNote(''); setMode('consume'); }}>🍳 Đã dùng</button>
              <button className="danger-btn" onClick={() => { setQty(String(item.quantity)); setNote(''); setMode('discard'); }}>🗑️ Bỏ đi / hỏng</button>
            </div>
          </div>
          {(mode === 'consume' || mode === 'discard') && (
            <Modal title={`${mode === 'discard' ? 'Bỏ đi' : 'Đã dùng'} ${item.food.name}`} onClose={() => setMode(null)}>
              <div className="stack">
                <Field label={`Lượng (${item.food.unit.name})`} hint={`Còn ${qtyUnit(item.quantity, item.food.unit.name)}`}>
                  <input className="num-input" value={qty} onChange={(e) => setQty(e.target.value)} autoFocus />
                </Field>
                <Field label="Ghi chú (tùy chọn)"><input value={note} onChange={(e) => setNote(e.target.value)} /></Field>
              </div>
              <div className="row end">
                <button className="ghost" onClick={() => setMode(null)}>Hủy</button>
                <button onClick={consume}>Ghi nhận</button>
              </div>
            </Modal>
          )}
          {mode === 'edit' && <FridgeForm item={item} onClose={(ok) => { setMode(null); if (ok) reload(); }} />}
        </>
      )}
    </Async>
  );
}
