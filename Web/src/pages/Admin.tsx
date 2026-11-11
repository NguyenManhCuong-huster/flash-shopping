import { useEffect, useState } from 'react';
import { adminApi } from '../api/endpoints';
import type { AuditLog } from '../api/types';
import { Async, Img, Pill, useAction, useConfirm, useLoad } from '../components/ui';
import { fmtDateTime } from '../lib/format';
import { useSession } from '../lib/session';

/** UC11 - Quản trị hệ thống. Quản trị viên không xem được dữ liệu riêng của từng gia đình. */
export function AdminPage() {
  const [tab, setTab] = useState<'users' | 'category' | 'unit' | 'logs'>('users');
  return (
    <>
      <div className="page-head"><h1>Quản trị hệ thống</h1></div>
      <div className="seg" style={{ marginBottom: 14 }}>
        {([['users', 'Người dùng'], ['category', 'Danh mục'], ['unit', 'Đơn vị'], ['logs', 'Nhật ký']] as const).map(([k, v]) => (
          <button key={k} className={tab === k ? 'on' : ''} onClick={() => setTab(k)}>{v}</button>
        ))}
      </div>
      {tab === 'users' && <Users />}
      {(tab === 'category' || tab === 'unit') && <Catalog key={tab} kind={tab} />}
      {tab === 'logs' && <Logs />}
    </>
  );
}

function Users() {
  const me = useSession().user;
  const confirm = useConfirm();
  const { run } = useAction();
  const [q, setQ] = useState('');
  const [query, setQuery] = useState('');
  useEffect(() => {
    const t = setTimeout(() => setQuery(q), 350);
    return () => clearTimeout(t);
  }, [q]);
  const { data, loading, error, reload } = useLoad(() => adminApi.users(query), [query]);
  return (
    <>
      <input placeholder="🔍 Tìm email, tên, username" value={q} onChange={(e) => setQ(e.target.value)} style={{ maxWidth: 360, marginBottom: 10 }} />
      <Async loading={loading} error={error} empty={!data?.users.length} onRetry={reload}>
        <div className="list">
          {data?.users.map((u) => (
            <div key={u.id} className="item">
              <Img src={u.imageUrl} round />
              <div className="grow">
                <div className="title">{u.name}{u.id === me?.id && ' (bạn)'} {u.systemRole === 'admin' && <Pill tone="warn">Admin</Pill>} {!u.isActive && <Pill tone="bad">Đã khóa</Pill>}</div>
                <div className="sub">{u.email}{u.username ? ` · @${u.username}` : ''} · {u.groupId ? `nhóm #${u.groupId}` : 'chưa có nhóm'}</div>
              </div>
              {u.id !== me?.id && (
                <>
                  <button className="small ghost" onClick={async () => {
                    if (u.isActive && !(await confirm(`Khóa ${u.email}? Người dùng bị đăng xuất khỏi mọi thiết bị.`, { ok: 'Khóa' }))) return;
                    await run(() => adminApi.updateUser({ userId: u.id, isActive: !u.isActive }), 'Đã cập nhật');
                    reload();
                  }}>{u.isActive ? 'Khóa' : 'Mở khóa'}</button>
                  <button className="small ghost" onClick={async () => {
                    await run(() => adminApi.updateUser({ userId: u.id, systemRole: u.systemRole === 'admin' ? 'user' : 'admin' }), 'Đã cập nhật quyền');
                    reload();
                  }}>{u.systemRole === 'admin' ? 'Thu quyền admin' : 'Cấp quyền admin'}</button>
                </>
              )}
            </div>
          ))}
        </div>
      </Async>
    </>
  );
}

function Catalog({ kind }: { kind: 'category' | 'unit' }) {
  const confirm = useConfirm();
  const { run } = useAction();
  const [name, setName] = useState('');
  const label = kind === 'category' ? 'danh mục' : 'đơn vị';
  const { data, loading, error, reload } = useLoad(() => adminApi.catalog(kind), [kind]);
  return (
    <>
      <div className="row" style={{ maxWidth: 420, marginBottom: 10 }}>
        <input style={{ flex: 1 }} placeholder={`Tên ${label} mới`} value={name} onChange={(e) => setName(e.target.value)} />
        <button onClick={async () => {
          if (!name.trim()) return;
          if (await run(() => adminApi.create(kind, name.trim()), 'Đã thêm')) { setName(''); reload(); }
        }}>+ Thêm</button>
      </div>
      <Async loading={loading} error={error} empty={!data?.length} onRetry={reload}>
        <div className="list" style={{ maxWidth: 520 }}>
          {data?.map((c) => (
            <div key={c.id} className="item">
              <div className="grow">{c.name}</div>
              <button className="small ghost" onClick={async () => {
                const n = prompt(`Đổi tên ${label}`, c.name);
                if (n?.trim() && n.trim() !== c.name) { await run(() => adminApi.rename(kind, c.name, n.trim()), 'Đã đổi tên'); reload(); }
              }}>Đổi tên</button>
              <button className="small ghost" onClick={async () => {
                if (await confirm(`Xóa "${c.name}"? Không thể xóa nếu đang được thực phẩm sử dụng.`)) { await run(() => adminApi.remove(kind, c.name), 'Đã xóa'); reload(); }
              }}>Xóa</button>
            </div>
          ))}
        </div>
      </Async>
    </>
  );
}

function Logs() {
  const [source, setSource] = useState('');
  const [page, setPage] = useState(1);
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const { data, loading, error, reload } = useLoad(async () => {
    const r = await adminApi.logs(source || undefined, page);
    setLogs((prev) => (page === 1 ? r.logs : [...prev, ...r.logs]));
    return r;
  }, [source, page]);
  return (
    <>
      <div className="chips">
        {['', 'app', 'ai', 'system'].map((s) => (
          <button key={s} className={`chip ${source === s ? 'on' : ''}`} onClick={() => { setSource(s); setPage(1); }}>{s || 'Tất cả'}</button>
        ))}
      </div>
      <Async loading={loading && !logs.length} error={error} empty={!logs.length} onRetry={reload}>
        <div className="card" style={{ padding: 0, overflowX: 'auto' }}>
          <table>
            <thead><tr><th>Thời gian</th><th>Thao tác</th><th>Người thực hiện</th><th>Đối tượng</th><th>Nguồn</th></tr></thead>
            <tbody>
              {logs.map((l) => (
                <tr key={l.id}>
                  <td style={{ whiteSpace: 'nowrap' }}>{fmtDateTime(l.occurredAt)}</td>
                  <td>{l.action}</td>
                  <td>{l.actor?.email ?? 'hệ thống'}</td>
                  <td>{l.entityType ? `${l.entityType} #${l.entityId}` : ''}</td>
                  <td>{l.source === 'ai' ? <Pill tone="info">AI</Pill> : l.source}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {data && data.page < data.totalPages && <div className="row end"><button className="ghost" onClick={() => setPage(page + 1)}>Tải thêm</button></div>}
      </Async>
    </>
  );
}
