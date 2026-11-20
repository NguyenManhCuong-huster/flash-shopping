import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { mealApi, recipeApi, shoppingApi } from '../api/endpoints';
import type { Food, MealName, MealPlan } from '../api/types';
import { MEALS } from '../api/types';
import { Async, Field, FoodPicker, Modal, NeedGroup, useAction, useConfirm, useLoad } from '../components/ui';
import { addDays, fmtDate, fmtWeekday, isoDate, qtyUnit, today } from '../lib/format';
import { useSession } from '../lib/session';

const monday = (d: Date) => addDays(d, -((d.getDay() + 6) % 7));

/** UC08 - Lập kế hoạch bữa ăn: lịch tuần; trưởng nhóm thêm/xóa; kiểm tra nguyên liệu. */
export function MealsPage() {
  const s = useSession();
  const confirm = useConfirm();
  const { run } = useAction();
  const [week, setWeek] = useState(monday(today()));
  const [selected, setSelected] = useState(today());
  const [adding, setAdding] = useState(false);
  const [check, setCheck] = useState<{ plan?: MealPlan; date?: string } | null>(null);
  const days = Array.from({ length: 7 }, (_, i) => addDays(week, i));
  const { data: plans, loading, error, reload } = useLoad(() => mealApi.plans(isoDate(week), isoDate(addDays(week, 6))), [week.getTime()]);
  if (!s.hasGroup) return <NeedGroup />;
  const dayPlans = (plans ?? []).filter((p) => p.date === isoDate(selected));

  return (
    <>
      <div className="page-head">
        <h1>Kế hoạch bữa ăn</h1>
        <button className="ghost" onClick={() => { setWeek(addDays(week, -7)); setSelected(addDays(week, -7)); }}>‹ Tuần trước</button>
        <span>{fmtDate(week)} – {fmtDate(addDays(week, 6))}</span>
        <button className="ghost" onClick={() => { setWeek(addDays(week, 7)); setSelected(addDays(week, 7)); }}>Tuần sau ›</button>
      </div>
      <div className="week">
        {days.map((d) => (
          <button key={d.getTime()} className={`day ${isoDate(d) === isoDate(selected) ? 'on' : ''} ${isoDate(d) === isoDate(today()) ? 'today' : ''}`} onClick={() => setSelected(d)}>
            <div style={{ fontSize: 12 }}>{fmtWeekday(d)}</div>
            <b>{d.getDate()}</b>
            {(plans ?? []).some((p) => p.date === isoDate(d)) && <div className="dot" />}
          </button>
        ))}
      </div>
      <div className="row" style={{ marginBottom: 8 }}>
        <b style={{ flex: 1 }}>{fmtDate(selected)}</b>
        {dayPlans.length > 0 && <button className="ghost" onClick={() => setCheck({ date: isoDate(selected) })}>🧾 Nguyên liệu cả ngày</button>}
        {s.isLeader && <button onClick={() => setAdding(true)}>+ Thêm bữa</button>}
      </div>
      <Async loading={loading} error={error} empty={false} onRetry={reload}>
        {MEALS.map((m) => (
          <div key={m}>
            <h2>Bữa {m}</h2>
            <div className="list">
              {dayPlans.filter((p) => p.mealName === m).length === 0 && <div className="item muted">Chưa có món</div>}
              {dayPlans.filter((p) => p.mealName === m).map((p) => (
                <div key={p.id} className="item">
                  <span>🍲</span>
                  <div className="grow">
                    <div className="title">{p.recipe?.name ?? p.food.name}</div>
                    <div className="sub">{p.recipe ? `Công thức · nguyên liệu chính: ${p.food.name}` : 'Thực phẩm'}</div>
                  </div>
                  <button className="small ghost" onClick={() => setCheck({ plan: p })}>Nguyên liệu</button>
                  {p.recipe && <Link className="btn small" to={`/recipes/${p.recipe.id}`} style={{ background: 'transparent', color: 'var(--primary)' }}>Công thức</Link>}
                  {s.isLeader && (
                    <button className="small ghost" onClick={async () => {
                      if (await confirm(`Xóa ${p.recipe?.name ?? p.food.name} khỏi bữa ${m}?`)) { await run(() => mealApi.remove(p.id), 'Đã xóa'); reload(); }
                    }}>Xóa</button>
                  )}
                </div>
              ))}
            </div>
          </div>
        ))}
      </Async>
      <p className="muted" style={{ fontSize: 13 }}>Lập kế hoạch không tự trừ tồn kho; sau khi nấu, ghi nhận "Đã dùng" trong tủ lạnh.</p>
      {adding && <MealForm date={selected} onClose={(ok) => { setAdding(false); if (ok) reload(); }} />}
      {check && <Ingredients {...check} onClose={() => setCheck(null)} />}
    </>
  );
}

function MealForm({ date, onClose }: { date: Date; onClose: (ok: boolean) => void }) {
  const { run, busy } = useAction();
  const recipes = useLoad(() => recipeApi.list().then((r) => r.recipes), []);
  const [d, setD] = useState(isoDate(date));
  const [meal, setMeal] = useState<MealName>('tối');
  const [byRecipe, setByRecipe] = useState(true);
  const [recipeId, setRecipeId] = useState('');
  const [food, setFood] = useState<Food | null>(null);
  const [err, setErr] = useState('');
  async function save() {
    if (byRecipe ? !recipeId : !food) return setErr(byRecipe ? 'Hãy chọn một công thức' : 'Hãy chọn thực phẩm');
    const ok = await run(() => mealApi.create(byRecipe ? { recipeId: Number(recipeId), timestamp: d, name: meal } : { foodName: food!.name, timestamp: d, name: meal }), 'Đã thêm vào kế hoạch');
    if (ok) onClose(true);
  }
  return (
    <Modal title="Thêm bữa ăn" onClose={() => onClose(false)}>
      <div className="stack">
        <Field label="Ngày"><input type="date" value={d} onChange={(e) => setD(e.target.value)} /></Field>
        <Field label="Bữa">
          <div className="seg">{MEALS.map((m) => <button key={m} className={meal === m ? 'on' : ''} onClick={() => setMeal(m)}>Bữa {m}</button>)}</div>
        </Field>
        <div className="seg">
          <button className={byRecipe ? 'on' : ''} onClick={() => setByRecipe(true)}>Theo công thức</button>
          <button className={!byRecipe ? 'on' : ''} onClick={() => setByRecipe(false)}>Theo thực phẩm</button>
        </div>
        {byRecipe ? (
          <Field label="Công thức" error={err}>
            <select value={recipeId} onChange={(e) => setRecipeId(e.target.value)}>
              <option value="">— Chọn công thức —</option>
              {recipes.data?.map((r) => <option key={r.id} value={r.id}>{r.name} ({r.food.name})</option>)}
            </select>
          </Field>
        ) : (
          <Field label="Thực phẩm / món" error={err}><FoodPicker value={food} onChange={setFood} /></Field>
        )}
      </div>
      <div className="row end">
        <button className="ghost" onClick={() => onClose(false)}>Hủy</button>
        <button onClick={save} disabled={busy}>Lưu</button>
      </div>
    </Modal>
  );
}

/** UC08 bước 3-4: nguyên liệu cần / có / thiếu; tùy chọn thêm phần thiếu vào danh sách mua (extend). */
function Ingredients({ plan, date, onClose }: { plan?: MealPlan; date?: string; onClose: () => void }) {
  const s = useSession();
  const nav = useNavigate();
  const { run, busy } = useAction();
  const { data, loading, error, reload } = useLoad(() => mealApi.ingredients(plan ? { planId: plan.id } : { date }), [plan?.id, date]);
  const sessions = useLoad(() => shoppingApi.sessions({ status: 'open' }).then((r) => r.sessions), []);
  const [target, setTarget] = useState('new');
  async function addMissing() {
    const r = await run(() => mealApi.missingToShopping({ ...(plan ? { planId: plan.id } : { date }), sessionId: target === 'new' ? undefined : Number(target) }), 'Đã thêm nguyên liệu còn thiếu vào danh sách mua');
    if (r?.data.sessionId) nav(`/shopping/${r.data.sessionId}`);
  }
  return (
    <Modal title={`Nguyên liệu: ${plan ? plan.recipe?.name ?? plan.food.name : `ngày ${fmtDate(date!)}`}`} onClose={onClose} wide>
      <Async loading={loading} error={error} empty={!data?.ingredients.length} onRetry={reload} emptyText="Không có nguyên liệu nào cần kiểm tra.">
        {data && (
          <>
            <p style={{ fontWeight: 'bold', color: data.missing.length ? 'var(--warn)' : 'var(--primary)' }}>
              {data.missing.length ? `Còn thiếu ${data.missing.length}/${data.ingredients.length} nguyên liệu` : 'Tủ lạnh đã đủ nguyên liệu'}
            </p>
            <table>
              <thead><tr><th>Nguyên liệu</th><th className="n">Cần</th><th className="n">Đang có</th><th className="n">Thiếu</th></tr></thead>
              <tbody>
                {data.ingredients.map((i) => (
                  <tr key={i.food.id}>
                    <td>{i.enough ? '✅' : '⚠️'} {i.food.name} {i.expiringSoon && <span className="pill warn">sắp hết hạn</span>}</td>
                    <td className="n">{i.requiredQuantity == null ? 'có trong tủ' : qtyUnit(i.requiredQuantity, i.food.unit)}</td>
                    <td className="n">{qtyUnit(i.availableQuantity, i.food.unit)}</td>
                    <td className="n" style={{ color: i.enough ? undefined : 'var(--warn)' }}>{i.enough ? '—' : qtyUnit(i.missingQuantity, i.food.unit)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {data.missing.length > 0 && s.isLeader && (
              <div className="row end">
                <select value={target} onChange={(e) => setTarget(e.target.value)} style={{ width: 'auto' }}>
                  <option value="new">Tạo danh sách mới</option>
                  {lists.data?.map((l) => <option key={l.id} value={l.id}>{l.name} ({fmtDate(l.date)})</option>)}
                </select>
                <button onClick={addMissing} disabled={busy}>🛒 Thêm phần thiếu vào danh sách mua</button>
              </div>
            )}
          </>
        )}
      </Async>
    </Modal>
  );
}
