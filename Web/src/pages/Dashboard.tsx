import { Link, useNavigate } from 'react-router-dom';
import { aiApi, fridgeApi, mealApi, shoppingApi } from '../api/endpoints';
import { Async, Img, NeedGroup, Pill, toneOf, useAction, useLoad } from '../components/ui';
import { fmtDate, isoDate, qtyUnit, statusLabel, today } from '../lib/format';
import { useSession } from '../lib/session';

export function Dashboard() {
  const s = useSession();
  const nav = useNavigate();
  const { run } = useAction();
  const { data, loading, error, reload } = useLoad(async () => {
    if (!s.hasGroup) return null;
    const t = isoDate(today());
    const [fridge, meals, lists, suggestions] = await Promise.all([
      fridgeApi.list({ expiringDays: 3 }),
      mealApi.plans(t, t),
      shoppingApi.lists({ status: 'open', assignedToMe: true }),
      s.isLeader ? aiApi.suggestions() : Promise.resolve([]),
    ]);
    return { fridge, meals, lists: lists.lists, suggestions };
  }, [s.hasGroup, s.isLeader]);

  return (
    <>
      <div className="page-head">
        <h1>Xin chào, {s.user?.name}</h1>
        <Link to="/ai" className="btn">🤖 Hỏi trợ lý AI</Link>
      </div>
      {!s.hasGroup ? (
        <NeedGroup />
      ) : (
        <Async loading={loading} error={error} empty={!data} onRetry={reload}>
          {data && (
            <>
              <div className="grid-3">
                <div className="card stat"><b style={{ color: 'var(--primary)' }}>{data.fridge.summary.total}</b>Trong tủ lạnh</div>
                <div className="card stat"><b style={{ color: 'var(--warn)' }}>{data.fridge.summary.expiring}</b>Sắp hết hạn (≤ 3 ngày)</div>
                <div className="card stat"><b style={{ color: 'var(--bad)' }}>{data.fridge.summary.expired}</b>Đã hết hạn</div>
              </div>

              {data.suggestions.length > 0 && (
                <>
                  <h2>Gợi ý từ trợ lý AI</h2>
                  <div className="list">
                    {data.suggestions.map((sg) => (
                      <div key={sg.id} className="item">
                        <span>💡</span>
                        <div className="grow">{sg.title}</div>
                        <button className="small" onClick={async () => {
                          const id = await run(() => aiApi.accept(sg.id));
                          if (id) nav(`/ai/${id}`);
                        }}>Xem & xác nhận</button>
                        <button className="small ghost" onClick={async () => { await run(() => aiApi.dismiss(sg.id)); reload(); }}>Bỏ qua</button>
                      </div>
                    ))}
                  </div>
                </>
              )}

              <div className="grid-2">
                <div>
                  <h2>Sắp hết hạn <Link to="/fridge" style={{ fontSize: 13, fontWeight: 'normal' }}>· Tủ lạnh</Link></h2>
                  <div className="list">
                    {data.fridge.items.length === 0 && <div className="item muted">Không có thực phẩm sắp hết hạn.</div>}
                    {data.fridge.items.slice(0, 6).map((i) => (
                      <Link key={i.id} to={`/fridge/${i.id}`} className="item click" style={{ color: '#000' }}>
                        <Img src={i.food.imageUrl} />
                        <div className="grow">
                          <div className="title">{i.food.name}</div>
                          <div className="sub">{qtyUnit(i.quantity, i.food.unit.name)} · HSD {fmtDate(i.useWithin)}</div>
                        </div>
                        <Pill tone={toneOf(i.status)}>{statusLabel(i.status, i.daysLeft)}</Pill>
                      </Link>
                    ))}
                  </div>
                </div>
                <div>
                  <h2>Bữa ăn hôm nay <Link to="/meals" style={{ fontSize: 13, fontWeight: 'normal' }}>· Lịch</Link></h2>
                  <div className="list">
                    {data.meals.length === 0 && <div className="item muted">Chưa lên kế hoạch cho hôm nay.</div>}
                    {data.meals.map((m) => (
                      <div key={m.id} className="item">
                        <span>🍲</span>
                        <div className="grow"><div className="title">{m.recipe?.name ?? m.food.name}</div><div className="sub">Bữa {m.mealName}</div></div>
                      </div>
                    ))}
                  </div>
                  <h2>Danh sách giao cho tôi</h2>
                  <div className="list">
                    {data.lists.length === 0 && <div className="item muted">Không có danh sách đang mở.</div>}
                    {data.lists.map((l) => (
                      <Link key={l.id} to={`/shopping/${l.id}`} className="item click" style={{ color: '#000' }}>
                        <span>🛒</span>
                        <div className="grow"><div className="title">{l.name}</div><div className="sub">Ngày {fmtDate(l.date)}</div></div>
                        <span className="num">{l.progress.bought}/{l.progress.total}</span>
                      </Link>
                    ))}
                  </div>
                </div>
              </div>
            </>
          )}
        </Async>
      )}
    </>
  );
}
