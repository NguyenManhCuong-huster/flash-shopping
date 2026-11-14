import { useState } from 'react';
import { insightApi } from '../api/endpoints';
import type { StockEvent } from '../api/types';
import { Async, Modal, NeedGroup, useLoad } from '../components/ui';
import { addDays, fmtDateTime, fmtQty, isoDate, qtyUnit, today } from '../lib/format';
import { useSession } from '../lib/session';

const LABELS: Record<string, string> = { purchase: 'Mua', add: 'Nhập tay', consume: 'Đã dùng', discard: 'Bỏ đi', adjust: 'Điều chỉnh', remove: 'Xóa khỏi tủ' };

/** UC10 - Thống kê mua và tiêu thụ. */
export function StatsPage() {
  const s = useSession();
  const [from, setFrom] = useState(isoDate(addDays(today(), -29)));
  const [to, setTo] = useState(isoDate(today()));
  const [history, setHistory] = useState(false);
  const { data: r, loading, error, reload } = useLoad(() => insightApi.stats(from, to), [from, to]);
  if (!s.hasGroup) return <NeedGroup />;
  const maxCat = Math.max(1, ...(r?.byCategory.map((c) => c.inEvents + c.consumeEvents + c.discardEvents) ?? [1]));
  const maxDay = Math.max(1, ...(r?.daily.map((d) => d.inEvents + d.consumeEvents + d.discardEvents) ?? [1]));
  return (
    <>
      <div className="page-head">
        <h1>Thống kê</h1>
        <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} style={{ width: 160 }} />
        <span>→</span>
        <input type="date" value={to} onChange={(e) => setTo(e.target.value)} style={{ width: 160 }} />
        {[7, 30, 90].map((d) => (
          <button key={d} className="chip" onClick={() => { setFrom(isoDate(addDays(today(), -(d - 1)))); setTo(isoDate(today())); }}>{d} ngày</button>
        ))}
        <button className="ghost" onClick={() => setHistory(true)}>🕘 Lịch sử biến động</button>
      </div>
      <Async loading={loading} error={error} empty={!r} onRetry={reload}>
        {r && (
          <>
            <div className="grid-3">
              <div className="card stat"><b style={{ color: 'var(--primary)' }}>{(r.totals.purchase ?? 0) + (r.totals.add ?? 0)}</b>Lần mua / nhập kho</div>
              <div className="card stat"><b style={{ color: 'var(--info)' }}>{r.totals.consume ?? 0}</b>Lần sử dụng</div>
              <div className="card stat"><b style={{ color: 'var(--bad)' }}>{r.totals.discard ?? 0}</b>Lần bỏ đi · lãng phí {(r.wasteRate * 100).toFixed(1)}%</div>
            </div>
            <p className="muted">Đi chợ: {r.shopping.lists} danh sách, đã mua {r.shopping.boughtTasks}/{r.shopping.tasks} món trong kỳ.</p>

            {r.daily.length > 0 && (
              <>
                <h2>Theo ngày</h2>
                <div className="card" style={{ display: 'flex', alignItems: 'flex-end', gap: 3, height: 150, overflowX: 'auto' }}>
                  {r.daily.map((d) => {
                    const h = (n: number) => `${(n / maxDay) * 110}px`;
                    return (
                      <div key={d.date} title={`${d.date}: nhập ${d.inEvents}, dùng ${d.consumeEvents}, bỏ ${d.discardEvents}`} style={{ flex: '1 0 14px', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
                        <div style={{ height: h(d.discardEvents), background: 'var(--bad)' }} />
                        <div style={{ height: h(d.consumeEvents), background: 'var(--info)' }} />
                        <div style={{ height: h(d.inEvents), background: 'var(--primary)' }} />
                        <div style={{ fontSize: 10, textAlign: 'center' }}>{d.date.slice(8)}</div>
                      </div>
                    );
                  })}
                </div>
                <p className="muted" style={{ fontSize: 12 }}>■ <span style={{ color: 'var(--primary)' }}>nhập kho</span> ■ <span style={{ color: 'var(--info)' }}>sử dụng</span> ■ <span style={{ color: 'var(--bad)' }}>bỏ đi</span></p>
              </>
            )}

            <div className="grid-2">
              <div>
                <h2>Theo danh mục (số lần)</h2>
                <div className="card stack">
                  {r.byCategory.length === 0 && <span className="muted">Chưa có dữ liệu</span>}
                  {r.byCategory.map((c) => {
                    const total = c.inEvents + c.consumeEvents + c.discardEvents;
                    return (
                      <div key={c.category} className="row" style={{ flexWrap: 'nowrap' }}>
                        <span style={{ width: 110 }}>{c.category}</span>
                        <div style={{ flex: 1 }}>
                          <div className="bars" style={{ width: `${(total / maxCat) * 100}%` }}>
                            <div style={{ flex: c.inEvents, background: 'var(--primary)' }} />
                            <div style={{ flex: c.consumeEvents, background: 'var(--info)' }} />
                            <div style={{ flex: c.discardEvents, background: 'var(--bad)' }} />
                          </div>
                        </div>
                        <span className="num" style={{ width: 30 }}>{total}</span>
                      </div>
                    );
                  })}
                </div>
              </div>
              <div>
                <h2>Theo thực phẩm</h2>
                <div className="card" style={{ padding: 0, overflowX: 'auto' }}>
                  <table>
                    <thead><tr><th>Thực phẩm</th><th className="n">Mua</th><th className="n">Dùng</th><th className="n">Bỏ</th></tr></thead>
                    <tbody>
                      {r.byFood.map((f) => (
                        <tr key={f.foodName + f.unit}>
                          <td>{f.foodName} <span className="muted">({f.unit})</span></td>
                          <td className="n">{fmtQty(f.purchased + f.added)}</td>
                          <td className="n">{fmtQty(f.consumed)}</td>
                          <td className="n" style={{ color: f.discarded ? 'var(--bad)' : undefined }}>{fmtQty(f.discarded)}</td>
                        </tr>
                      ))}
                      {r.byFood.length === 0 && <tr><td colSpan={4} className="muted">Chưa có biến động kho trong kỳ</td></tr>}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </>
        )}
      </Async>
      {history && <History from={from} to={to} onClose={() => setHistory(false)} />}
    </>
  );
}

/** Lịch sử biến động kho, tải thêm 50 bản ghi mỗi lần (NFR08). */
function History({ from, to, onClose }: { from: string; to: string; onClose: () => void }) {
  const [type, setType] = useState('');
  const [page, setPage] = useState(1);
  const [items, setItems] = useState<StockEvent[]>([]);
  const { data, loading, error, reload } = useLoad(async () => {
    const r = await insightApi.events(from, to, type || undefined, page);
    setItems((prev) => (page === 1 ? r.events : [...prev, ...r.events]));
    return r;
  }, [type, page]);
  return (
    <Modal title="Lịch sử biến động kho" onClose={onClose} wide>
      <div className="chips">
        <button className={`chip ${type === '' ? 'on' : ''}`} onClick={() => { setType(''); setPage(1); }}>Tất cả</button>
        {Object.entries(LABELS).map(([k, v]) => <button key={k} className={`chip ${type === k ? 'on' : ''}`} onClick={() => { setType(k); setPage(1); }}>{v}</button>)}
      </div>
      <Async loading={loading && !items.length} error={error} empty={!items.length} onRetry={reload} emptyText="Không có biến động">
        <div className="list">
          {items.map((e) => {
            const plus = e.type === 'purchase' || e.type === 'add' || (e.type === 'adjust' && e.quantity >= 0);
            return (
              <div key={e.id} className="item">
                <div className="grow">
                  <div className="title">{LABELS[e.type] ?? e.type}: {e.foodName}</div>
                  <div className="sub">{fmtDateTime(e.occurredAt)}{e.actor ? ` · ${e.actor.name}` : ''}{e.note ? ` · ${e.note}` : ''}</div>
                </div>
                <span className="num" style={{ color: plus ? 'var(--primary)' : 'var(--bad)' }}>{plus ? '+' : '−'}{qtyUnit(Math.abs(e.quantity), e.unit)}</span>
              </div>
            );
          })}
        </div>
        {data && data.page < data.totalPages && <div className="row end"><button className="ghost" onClick={() => setPage(page + 1)}>Tải thêm</button></div>}
      </Async>
    </Modal>
  );
}
