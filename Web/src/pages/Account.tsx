import { useState } from 'react';
import { groupApi, userApi } from '../api/endpoints';
import type { Member } from '../api/types';
import { Async, Field, Img, Pill, useAction, useConfirm, useLoad } from '../components/ui';
import { useSession } from '../lib/session';

const USERNAME_RE = /^[A-Za-z0-9_.]{4,14}$/;

/** UC02 - Quản lý nhóm gia đình. */
export function GroupPage() {
  const s = useSession();
  const confirm = useConfirm();
  const { run, busy } = useAction();
  const [name, setName] = useState('');
  const [username, setUsername] = useState('');
  const { data, loading, error, reload } = useLoad(() => (s.hasGroup ? groupApi.get() : Promise.resolve(null)), [s.hasGroup]);
  const after = async () => {
    await s.refresh();
    reload();
  };

  if (!s.hasGroup) {
    return (
      <div className="card" style={{ maxWidth: 480 }}>
        <h1>Tạo nhóm gia đình</h1>
        <p className="muted">Người tạo nhóm là trưởng nhóm, có thể thêm thành viên bằng tên người dùng.</p>
        <Field label="Tên nhóm (tùy chọn)"><input value={name} onChange={(e) => setName(e.target.value)} placeholder={`Gia đình ${s.user?.name}`} /></Field>
        <div className="row end"><button disabled={busy} onClick={async () => { if (await run(() => groupApi.create(name.trim() || undefined), 'Đã tạo nhóm')) after(); }}>Tạo nhóm</button></div>
        <p className="muted">
          Muốn tham gia nhóm có sẵn? {s.user?.username ? <>Gửi tên người dùng <b>@{s.user.username}</b> cho trưởng nhóm.</> : 'Hãy đặt tên người dùng trong Hồ sơ rồi gửi cho trưởng nhóm.'}
        </p>
      </div>
    );
  }

  const members = data?.group.members ?? [];
  const memberAction = async (m: Member, kind: 'remove' | 'leader') => {
    if (kind === 'remove' && (await confirm(`Xóa ${m.name} khỏi nhóm? Các danh sách giao cho người này sẽ về "chưa giao".`))) {
      await run(() => groupApi.remove(m.username!), `Đã xóa ${m.name}`);
      after();
    }
    if (kind === 'leader' && (await confirm(`${m.name} sẽ trở thành trưởng nhóm, bạn trở thành thành viên.`, { title: 'Chuyển quyền trưởng nhóm', ok: 'Chuyển' }))) {
      await run(() => groupApi.transfer(m.username!), 'Đã chuyển quyền trưởng nhóm');
      after();
    }
  };

  return (
    <Async loading={loading} error={error} empty={!data} onRetry={reload}>
      <div className="page-head">
        <h1>{data?.group.name}</h1>
        {s.isLeader && (
          <button className="ghost" onClick={async () => {
            const n = prompt('Tên nhóm mới', data?.group.name);
            if (n?.trim()) { await run(() => groupApi.rename(n.trim()), 'Đã đổi tên nhóm'); after(); }
          }}>Đổi tên</button>
        )}
      </div>
      <p className="muted">Thành viên chia sẻ chung danh sách mua sắm, tủ lạnh, công thức và kế hoạch bữa ăn.</p>
      {s.isLeader && (
        <div className="row" style={{ marginBottom: 12, maxWidth: 480 }}>
          <input style={{ flex: 1 }} placeholder="Tên người dùng cần thêm" value={username} onChange={(e) => setUsername(e.target.value)} />
          <button disabled={busy} onClick={async () => {
            if (!USERNAME_RE.test(username.trim())) return alert('Tên người dùng 4-14 ký tự: chữ không dấu, số, dấu chấm, gạch dưới');
            if (await run(() => groupApi.add(username.trim()), `Đã thêm ${username}`)) { setUsername(''); after(); }
          }}>+ Thêm thành viên</button>
        </div>
      )}
      <div className="list">
        {members.map((m) => (
          <div key={m.id} className="item">
            <Img src={m.imageUrl} round />
            <div className="grow">
              <div className="title">{m.name}{m.id === s.user?.id && ' (bạn)'} {m.role === 'admin' && <Pill>Trưởng nhóm</Pill>}</div>
              <div className="sub">{m.username ? `@${m.username}` : 'Chưa đặt username'}</div>
            </div>
            {s.isLeader && m.id !== s.user?.id && m.username && (
              <>
                <button className="small ghost" onClick={() => memberAction(m, 'leader')}>Chuyển trưởng nhóm</button>
                <button className="small ghost" onClick={() => memberAction(m, 'remove')}>Xóa</button>
              </>
            )}
          </div>
        ))}
      </div>
      <div className="row end">
        <button className="danger-btn" onClick={async () => {
          const alone = members.length <= 1;
          if (await confirm(alone ? 'Bạn là thành viên cuối cùng. Rời nhóm sẽ GIẢI TÁN nhóm và xóa toàn bộ dữ liệu của nhóm.' : 'Bạn sẽ không còn xem được dữ liệu của nhóm.', { title: 'Rời nhóm', ok: 'Rời nhóm' })) {
            if (await run(() => groupApi.leave(), 'Đã rời nhóm')) after();
          }
        }}>Rời nhóm</button>
      </div>
    </Async>
  );
}

const TIMEZONES = ['Asia/Ho_Chi_Minh', 'Asia/Bangkok', 'Asia/Singapore', 'Asia/Tokyo', 'Asia/Seoul', 'Europe/London', 'Europe/Paris', 'America/New_York', 'Australia/Sydney', 'UTC'];

/** UC12 - Quản lý tài khoản cá nhân. */
export function ProfilePage() {
  const s = useSession();
  const confirm = useConfirm();
  const { run, busy } = useAction();
  const u = s.user!;
  const [f, setF] = useState({ name: u.name, username: u.username ?? '', language: u.language, timezone: u.timezone });
  const [image, setImage] = useState<File | null>(null);
  const [pw, setPw] = useState({ old: '', next: '' });
  const [errors, setErrors] = useState<Record<string, string>>({});

  async function save() {
    const e: Record<string, string> = {};
    if (f.name.trim().length < 4 || f.name.trim().length > 29) e.name = 'Họ tên cần từ 4 đến 29 ký tự';
    if (f.username && !USERNAME_RE.test(f.username)) e.username = '4-14 ký tự: chữ không dấu, số, dấu chấm, gạch dưới';
    setErrors(e);
    if (Object.keys(e).length) return;
    const fields = {
      name: f.name.trim() !== u.name ? f.name.trim() : undefined,
      username: f.username !== (u.username ?? '') ? f.username : undefined,
      language: f.language !== u.language ? f.language : undefined,
      timezone: f.timezone !== u.timezone ? f.timezone : undefined,
    };
    if (!Object.values(fields).some(Boolean) && !image) return;
    const nu = await run(() => userApi.update(fields, image), 'Đã lưu hồ sơ');
    if (nu) s.setUser(nu);
  }

  return (
    <div className="grid-2">
      <div className="card stack">
        <h1>Hồ sơ cá nhân</h1>
        <div className="row"><Img src={u.imageUrl} size={64} round /> <span className="muted">{u.email}</span></div>
        <Field label="Ảnh đại diện"><input type="file" accept="image/jpeg,image/png,image/webp" onChange={(e) => setImage(e.target.files?.[0] ?? null)} /></Field>
        <Field label="Họ tên" error={errors.name}><input value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} /></Field>
        <Field label="Tên người dùng (để được thêm vào nhóm)" error={errors.username}><input value={f.username} onChange={(e) => setF({ ...f, username: e.target.value })} /></Field>
        <Field label="Ngôn ngữ">
          <select value={f.language} onChange={(e) => setF({ ...f, language: e.target.value })}><option value="vi">Tiếng Việt</option><option value="en">English</option></select>
        </Field>
        <Field label="Múi giờ">
          <select value={f.timezone} onChange={(e) => setF({ ...f, timezone: e.target.value })}>
            {[...new Set([f.timezone, ...TIMEZONES])].map((t) => <option key={t}>{t}</option>)}
          </select>
        </Field>
        <div className="row end"><button onClick={save} disabled={busy}>Lưu</button></div>
      </div>
      <div className="stack">
        <div className="card stack">
          <h3>Đổi mật khẩu</h3>
          <Field label="Mật khẩu hiện tại"><input type="password" value={pw.old} onChange={(e) => setPw({ ...pw, old: e.target.value })} /></Field>
          <Field label="Mật khẩu mới (6-20 ký tự)"><input type="password" value={pw.next} onChange={(e) => setPw({ ...pw, next: e.target.value })} /></Field>
          <div className="row end">
            <button disabled={busy} onClick={async () => {
              if (pw.next.length < 6 || pw.next.length > 20) return alert('Mật khẩu mới cần 6-20 ký tự');
              if (pw.next === pw.old) return alert('Mật khẩu mới phải khác mật khẩu cũ');
              if (await run(() => userApi.changePassword(pw.old, pw.next), 'Đã đổi mật khẩu. Các thiết bị khác đã bị đăng xuất.')) setPw({ old: '', next: '' });
            }}>Đổi mật khẩu</button>
          </div>
        </div>
        <div className="card">
          <h3 className="danger">Xóa tài khoản</h3>
          <p className="muted">Tài khoản và lịch sử trò chuyện AI bị xóa vĩnh viễn. Nếu là trưởng nhóm, quyền được chuyển cho thành viên khác.</p>
          <button className="danger-btn" onClick={async () => {
            if (await confirm('Xóa vĩnh viễn tài khoản của bạn?', { ok: 'Xóa vĩnh viễn' })) {
              if (await run(() => userApi.deleteAccount())) s.logout();
            }
          }}>Xóa tài khoản</button>
        </div>
      </div>
    </div>
  );
}
