import { useEffect, useState } from 'react';
import { catalogApi, foodApi } from '../api/endpoints';
import type { Food } from '../api/types';
import { Async, Field, Img, Modal, NeedGroup, useAction, useConfirm, useLoad } from '../components/ui';
import { useSession } from '../lib/session';

/** Thực phẩm của nhóm: thành viên được thêm, trưởng nhóm được sửa/xóa. */
export function FoodsPage() {
  const s = useSession();
  const confirm = useConfirm();
  const { run } = useAction();
  const [q, setQ] = useState('');
  const [query, setQuery] = useState('');
  const [cat, setCat] = useState<number | undefined>();
  const [editing, setEditing] = useState<Food | 'new' | null>(null);
  useEffect(() => {
    const t = setTimeout(() => setQuery(q), 350);
    return () => clearTimeout(t);
  }, [q]);
  const cats = useLoad(() => catalogApi.categories(), []);
  const { data, loading, error, reload } = useLoad(() => foodApi.list(query, cat), [query, cat]);
  if (!s.hasGroup) return <NeedGroup />;
  return (
    <>
      <div className="page-head">
        <h1>Thực phẩm của nhóm</h1>
        <input style={{ maxWidth: 260 }} placeholder="🔍 Tìm thực phẩm" value={q} onChange={(e) => setQ(e.target.value)} />
        <button onClick={() => setEditing('new')}>+ Thêm thực phẩm</button>
      </div>
      <div className="chips">
        <button className={`chip ${cat === undefined ? 'on' : ''}`} onClick={() => setCat(undefined)}>Tất cả</button>
        {cats.data?.map((c) => <button key={c.id} className={`chip ${cat === c.id ? 'on' : ''}`} onClick={() => setCat(c.id)}>{c.name}</button>)}
      </div>
      <Async loading={loading} error={error} empty={!data?.foods.length} onRetry={reload} emptyText="Chưa có thực phẩm. Thêm để dùng cho tủ lạnh, danh sách mua và công thức.">
        <div className="list">
          {data?.foods.map((f) => (
            <div key={f.id} className="item">
              <Img src={f.imageUrl} />
              <div className="grow"><div className="title">{f.name}</div><div className="sub">{f.category.name} · đơn vị: {f.unit.name}</div></div>
              {s.isLeader && (
                <>
                  <button className="small ghost" onClick={() => setEditing(f)}>Sửa</button>
                  <button className="small ghost" onClick={async () => {
                    if (await confirm(`Xóa "${f.name}" sẽ xóa luôn mục tủ lạnh, nhiệm vụ mua, kế hoạch và công thức liên quan.`)) {
                      await run(() => foodApi.remove(f.name), `Đã xóa ${f.name}`);
                      reload();
                    }
                  }}>Xóa</button>
                </>
              )}
            </div>
          ))}
        </div>
      </Async>
      {editing && <FoodForm food={editing === 'new' ? undefined : editing} onClose={(ok) => { setEditing(null); if (ok) reload(); }} />}
    </>
  );
}

function FoodForm({ food, onClose }: { food?: Food; onClose: (ok: boolean) => void }) {
  const { run, busy } = useAction();
  const cats = useLoad(() => catalogApi.categories(), []);
  const units = useLoad(() => catalogApi.units(), []);
  const [f, setF] = useState({ name: food?.name ?? '', category: food?.category.name ?? '', unit: food?.unit.name ?? '' });
  const [image, setImage] = useState<File | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  async function save() {
    const e: Record<string, string> = {};
    if (!f.name.trim()) e.name = 'Tên thực phẩm không được để trống';
    if (!f.category) e.category = 'Hãy chọn danh mục';
    if (!f.unit) e.unit = 'Hãy chọn đơn vị đo';
    setErrors(e);
    if (Object.keys(e).length) return;
    let ok;
    if (food) {
      const fields = {
        name: food.name,
        newName: f.name.trim() !== food.name ? f.name.trim() : undefined,
        newCategory: f.category !== food.category.name ? f.category : undefined,
        newUnit: f.unit !== food.unit.name ? f.unit : undefined,
      };
      if (!fields.newName && !fields.newCategory && !fields.newUnit && !image) return onClose(false);
      ok = await run(() => foodApi.save(fields, image, true), 'Đã cập nhật');
    } else {
      ok = await run(() => foodApi.save({ name: f.name.trim(), foodCategoryName: f.category, unitName: f.unit }, image, false), 'Đã thêm thực phẩm');
    }
    if (ok) onClose(true);
  }
  return (
    <Modal title={food ? 'Sửa thực phẩm' : 'Thêm thực phẩm'} onClose={() => onClose(false)}>
      <div className="stack">
        <Field label="Tên thực phẩm" error={errors.name}><input value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} autoFocus /></Field>
        <Field label="Danh mục" error={errors.category}>
          <select value={f.category} onChange={(e) => setF({ ...f, category: e.target.value })}>
            <option value="">— Chọn —</option>
            {cats.data?.map((c) => <option key={c.id}>{c.name}</option>)}
          </select>
        </Field>
        <Field label="Đơn vị đo" error={errors.unit}>
          <select value={f.unit} onChange={(e) => setF({ ...f, unit: e.target.value })}>
            <option value="">— Chọn —</option>
            {units.data?.map((u) => <option key={u.id}>{u.name}</option>)}
          </select>
        </Field>
        <Field label="Ảnh (jpg, png, webp ≤ 5MB)">
          <input type="file" accept="image/jpeg,image/png,image/webp" onChange={(e) => setImage(e.target.files?.[0] ?? null)} />
        </Field>
      </div>
      <div className="row end">
        <button className="ghost" onClick={() => onClose(false)}>Hủy</button>
        <button onClick={save} disabled={busy}>Lưu</button>
      </div>
    </Modal>
  );
}
