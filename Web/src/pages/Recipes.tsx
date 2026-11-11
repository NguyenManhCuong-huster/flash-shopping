import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { recipeApi } from '../api/endpoints';
import type { Food, Recipe } from '../api/types';
import { Async, Field, FoodPicker, Img, Modal, Pill, useAction, useConfirm, useLoad, useToast } from '../components/ui';
import { htmlToSteps, parseQty, qtyUnit, stepsToHtml } from '../lib/format';
import { useSession } from '../lib/session';

/** UC07 - danh sách & tìm kiếm công thức. */
export function RecipesPage() {
  const [q, setQ] = useState('');
  const [query, setQuery] = useState('');
  const [adding, setAdding] = useState(false);
  const nav = useNavigate();
  useEffect(() => {
    const t = setTimeout(() => setQuery(q), 350);
    return () => clearTimeout(t);
  }, [q]);
  const { data, loading, error, reload } = useLoad(() => recipeApi.list(query), [query]);
  return (
    <>
      <div className="page-head">
        <h1>Công thức nấu ăn</h1>
        <input style={{ maxWidth: 280 }} placeholder="🔍 Tên món, mô tả, nguyên liệu chính" value={q} onChange={(e) => setQ(e.target.value)} />
        <Link to="/suggestions" className="btn" style={{ background: 'transparent', color: 'var(--primary)', border: '1px solid var(--line)' }}>✨ Gợi ý từ tủ lạnh</Link>
        <button onClick={() => setAdding(true)}>+ Thêm công thức</button>
      </div>
      <Async loading={loading} error={error} empty={!data?.recipes.length} onRetry={reload} emptyText="Chưa có công thức nào.">
        <div className="list">
          {data?.recipes.map((r) => (
            <Link key={r.id} to={`/recipes/${r.id}`} className="item click" style={{ color: '#000' }}>
              <Img src={r.food.imageUrl} />
              <div className="grow">
                <div className="title">{r.name}</div>
                <div className="sub">{r.description}</div>
                <div className="sub">Nguyên liệu chính: {r.food.name}{r.ingredients?.length ? ` + ${r.ingredients.length} nguyên liệu` : ''}</div>
              </div>
            </Link>
          ))}
        </div>
      </Async>
      {adding && <RecipeForm onClose={(id) => { setAdding(false); if (id) nav(`/recipes/${id}`); }} />}
    </>
  );
}

export function RecipeDetail() {
  const id = Number(useParams().id);
  const s = useSession();
  const nav = useNavigate();
  const confirm = useConfirm();
  const { run } = useAction();
  const [editing, setEditing] = useState(false);
  const { data: r, loading, error, reload } = useLoad(() => recipeApi.get(id), [id]);
  const canEdit = !!r && (r.createdBy?.id === s.user?.id || s.isLeader);
  return (
    <Async loading={loading} error={error} empty={!r} onRetry={reload}>
      {r && (
        <>
          <div className="page-head">
            <h1>{r.name}</h1>
            {canEdit && (
              <>
                <button className="ghost" onClick={() => setEditing(true)}>Sửa</button>
                <button className="ghost" onClick={async () => {
                  if (await confirm(`Xóa công thức "${r.name}"?`)) { if (await run(() => recipeApi.remove(r.id), 'Đã xóa công thức')) nav('/recipes'); }
                }}>Xóa</button>
              </>
            )}
          </div>
          <p>{r.description}</p>
          {r.createdBy && <p className="muted">Người tạo: {r.createdBy.name}</p>}
          <div className="grid-2">
            <div>
              <h2>Nguyên liệu</h2>
              <div className="list">
                <div className="item"><span>⭐</span><div className="grow">{r.food.name} <span className="muted">(nguyên liệu chính)</span></div></div>
                {r.ingredients?.map((i) => (
                  <div key={i.food.id} className="item"><span>•</span><div className="grow">{i.food.name}</div>{i.quantity != null && <span className="num">{qtyUnit(i.quantity, i.food.unit)}</span>}</div>
                ))}
              </div>
            </div>
            <div>
              <h2>Cách làm</h2>
              <div className="card" style={{ whiteSpace: 'pre-line', lineHeight: 1.7 }}>{htmlToSteps(r.htmlContent)}</div>
            </div>
          </div>
          {editing && <RecipeForm recipe={r} onClose={(saved) => { setEditing(false); if (saved) reload(); }} />}
        </>
      )}
    </Async>
  );
}

function RecipeForm({ recipe, onClose }: { recipe?: Recipe; onClose: (id?: number) => void }) {
  const toast = useToast();
  const [main, setMain] = useState<string | null>(recipe?.food.name ?? null);
  const [f, setF] = useState({ name: recipe?.name ?? '', description: recipe?.description ?? '', steps: htmlToSteps(recipe?.htmlContent) });
  const [ings, setIngs] = useState(recipe?.ingredients?.map((i) => ({ name: i.food.name, unit: i.food.unit, qty: i.quantity == null ? '' : String(i.quantity) })) ?? []);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);

  async function save() {
    const e: Record<string, string> = {};
    if (!f.name.trim()) e.name = 'Tên món không được để trống';
    if (!main) e.main = 'Hãy chọn nguyên liệu chính';
    if (!f.description.trim()) e.description = 'Mô tả không được để trống';
    if (!f.steps.trim()) e.steps = 'Cách làm không được để trống';
    if (ings.some((i) => i.qty.trim() && !(parseQty(i.qty) > 0))) e.ings = 'Định lượng phải là số lớn hơn 0 hoặc để trống';
    setErrors(e);
    if (Object.keys(e).length) return;
    const ingredients = ings.map((i) => ({ foodName: i.name, quantity: i.qty.trim() ? parseQty(i.qty) : null }));
    setBusy(true);
    try {
      const r = recipe
        ? await recipeApi.update({
            recipeId: recipe.id, newName: f.name.trim(), newDescription: f.description.trim(), newHtmlContent: stepsToHtml(f.steps), newIngredients: ingredients,
            ...(main !== recipe.food.name ? { newFoodName: main } : {}),
          })
        : await recipeApi.create({ foodName: main, name: f.name.trim(), description: f.description.trim(), htmlContent: stepsToHtml(f.steps), ingredients });
      toast({ text: 'Đã lưu công thức' });
      onClose(r.data.recipe.id);
    } catch (err) {
      const ae = err as { message: string; data?: { foodName?: string; reason?: string } };
      toast({ text: ae.data?.reason ? `${ae.message}: ${ae.data.foodName ?? ''} ${ae.data.reason}` : ae.message, error: true });
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title={recipe ? 'Sửa công thức' : 'Thêm công thức'} onClose={() => onClose()} wide>
      <div className="stack">
        <Field label="Tên món" error={errors.name}><input value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} /></Field>
        <Field label="Nguyên liệu chính" error={errors.main}>
          <FoodPicker value={main ? ({ name: main, unit: { name: '' } } as Food) : null} onChange={(x) => setMain(x.name)} />
        </Field>
        <Field label="Mô tả ngắn" error={errors.description}><input value={f.description} onChange={(e) => setF({ ...f, description: e.target.value })} /></Field>
        <Field label="Cách làm (mỗi dòng một bước)" error={errors.steps}>
          <textarea rows={6} value={f.steps} onChange={(e) => setF({ ...f, steps: e.target.value })} />
        </Field>
        <Field label={`Nguyên liệu khác (${ings.length})`} error={errors.ings}>
          <div className="stack">
            {ings.map((i, idx) => (
              <div key={i.name} className="row" style={{ flexWrap: 'nowrap' }}>
                <span style={{ flex: 2 }}>{i.name}</span>
                <input style={{ flex: 1 }} className="num-input" placeholder="tùy ý" value={i.qty} onChange={(e) => setIngs(ings.map((x, k) => (k === idx ? { ...x, qty: e.target.value } : x)))} />
                <span className="muted" style={{ width: 36 }}>{i.unit}</span>
                <button className="icon" onClick={() => setIngs(ings.filter((_, k) => k !== idx))}>✕</button>
              </div>
            ))}
            <FoodPicker value={null} placeholder="+ Thêm nguyên liệu..." onChange={(x) => {
              if (ings.some((i) => i.name.toLowerCase() === x.name.toLowerCase())) return toast({ text: `${x.name} đã có trong danh sách`, error: true });
              setIngs([...ings, { name: x.name, unit: x.unit.name, qty: '' }]);
            }} />
          </div>
        </Field>
      </div>
      <div className="row end">
        <button className="ghost" onClick={() => onClose()}>Hủy</button>
        <button onClick={save} disabled={busy}>{busy && <span className="spinner" />} Lưu</button>
      </div>
    </Modal>
  );
}

/** UC09 - Gợi ý món: ưu tiên món nấu được ngay và dùng đồ sắp hết hạn; hiển thị phần thiếu. */
export function SuggestionsPage() {
  const [only, setOnly] = useState(false);
  const { data, loading, error, reload } = useLoad(() => recipeApi.suggest(only), [only]);
  return (
    <>
      <div className="page-head">
        <h1>Gợi ý món từ tủ lạnh</h1>
        <label className="row"><input type="checkbox" checked={only} onChange={(e) => setOnly(e.target.checked)} style={{ width: 18 }} /> Chỉ món nấu được ngay</label>
      </div>
      <Async loading={loading} error={error} empty={!data?.length} onRetry={reload} emptyText={only ? 'Chưa có món nào đủ nguyên liệu.' : 'Hãy thêm công thức để nhận gợi ý.'}>
        <div className="list">
          {data?.map((sg) => (
            <Link key={sg.recipe.id} to={`/recipes/${sg.recipe.id}`} className="item click" style={{ color: '#000' }}>
              <div className="grow">
                <div className="title">{sg.recipe.name}</div>
                {sg.expiringIngredients.length > 0 && <div className="sub" style={{ color: 'var(--warn)' }}>Dùng đồ sắp hết hạn: {sg.expiringIngredients.join(', ')}</div>}
                {sg.missing.length > 0 && (
                  <div className="sub">Còn thiếu: {sg.missing.map((m) => (m.requiredQuantity == null ? m.food.name : `${m.food.name} ${qtyUnit(m.missingQuantity, m.food.unit)}`)).join(', ')}</div>
                )}
              </div>
              {sg.canCook ? <Pill>Nấu được ngay</Pill> : <Pill tone="warn">Có {sg.availableIngredients}/{sg.totalIngredients}</Pill>}
            </Link>
          ))}
        </div>
      </Async>
    </>
  );
}
