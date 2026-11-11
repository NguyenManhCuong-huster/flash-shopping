import { useState, type FormEvent } from 'react';
import { ApiError } from '../api/client';
import { authApi } from '../api/endpoints';
import { Field, useToast } from '../components/ui';
import { useSession } from '../lib/session';

type Mode = { kind: 'login' } | { kind: 'register' } | { kind: 'verify'; email: string; token: string | null };

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

/** UC01 - Đăng nhập, đăng ký, xác minh email bằng OTP. */
export function AuthPage() {
  const session = useSession();
  const toast = useToast();
  const [mode, setMode] = useState<Mode>({ kind: 'login' });
  const [form, setForm] = useState({ name: '', email: '', password: '', confirm: '', code: '' });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const set = (k: keyof typeof form) => (e: { target: { value: string } }) => setForm({ ...form, [k]: e.target.value });

  // NFR05: lỗi chỉ rõ trường, lý do, cách sửa; dữ liệu hợp lệ được giữ lại
  function validate() {
    const e: Record<string, string> = {};
    if (mode.kind === 'verify') {
      if (!/^\d{6}$/.test(form.code.trim())) e.code = 'Mã xác minh gồm 6 chữ số trong email';
    } else {
      if (!EMAIL_RE.test(form.email.trim())) e.email = 'Email không hợp lệ, ví dụ: ten@gmail.com';
      if (form.password.length < 6 || form.password.length > 20) e.password = `Mật khẩu cần 6-20 ký tự (hiện có ${form.password.length})`;
      if (mode.kind === 'register') {
        const n = form.name.trim().length;
        if (n < 4 || n > 29) e.name = 'Họ tên cần từ 4 đến 29 ký tự';
        if (form.confirm !== form.password) e.confirm = 'Mật khẩu nhập lại không khớp';
      }
    }
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  async function submit(ev: FormEvent) {
    ev.preventDefault();
    if (!validate()) return;
    setBusy(true);
    try {
      if (mode.kind === 'login') {
        try {
          await session.login(form.email, form.password);
        } catch (e) {
          if (e instanceof ApiError && e.code === '00044') {
            const token = await authApi.sendCode(form.email.trim()).catch(() => null);
            toast({ text: 'Email chưa được xác minh. Mã mới đã được gửi.' });
            setMode({ kind: 'verify', email: form.email.trim(), token });
            return;
          }
          throw e;
        }
      } else if (mode.kind === 'register') {
        const token = await authApi.register({ email: form.email.trim(), password: form.password, name: form.name.trim() });
        toast({ text: 'Đăng ký thành công. Mã xác minh đã được gửi tới email.' });
        setMode({ kind: 'verify', email: form.email.trim(), token });
      } else {
        let token = mode.token;
        if (!token) token = await authApi.sendCode(mode.email);
        if (!token) {
          toast({ text: 'Email đã được xác minh, hãy đăng nhập.' });
          setMode({ kind: 'login' });
          return;
        }
        await authApi.verify(form.code.trim(), token);
        toast({ text: 'Xác minh thành công. Hãy đăng nhập.' });
        setMode({ kind: 'login' });
      }
    } catch (e) {
      toast({ text: (e as Error).message, error: true });
    } finally {
      setBusy(false);
    }
  }

  async function resend() {
    if (mode.kind !== 'verify') return;
    try {
      const token = await authApi.sendCode(mode.email);
      setMode({ ...mode, token });
      toast({ text: `Đã gửi mã mới tới ${mode.email}` });
    } catch (e) {
      toast({ text: (e as Error).message, error: true });
    }
  }

  return (
    <div className="auth">
      <form className="card stack" onSubmit={submit} noValidate>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 46 }}>🧺</div>
          <h1>Đi chợ tiện lợi</h1>
          <p className="muted">
            {mode.kind === 'login' ? 'Mua sắm, tủ lạnh và bữa ăn cho cả nhà' : mode.kind === 'register' ? 'Tạo tài khoản mới' : `Nhập mã 6 số đã gửi tới ${mode.email}`}
          </p>
        </div>
        {session.expiredMessage && mode.kind === 'login' && <p className="danger">{session.expiredMessage}</p>}

        {mode.kind === 'verify' ? (
          <Field label="Mã xác minh" error={errors.code} hint="Môi trường dev: xem email tại http://localhost:8025">
            <input value={form.code} onChange={set('code')} maxLength={6} inputMode="numeric" autoFocus style={{ fontSize: 22, letterSpacing: 8, textAlign: 'center' }} />
          </Field>
        ) : (
          <>
            {mode.kind === 'register' && (
              <Field label="Họ tên" error={errors.name}>
                <input value={form.name} onChange={set('name')} autoFocus />
              </Field>
            )}
            <Field label="Email" error={errors.email}>
              <input type="email" value={form.email} onChange={set('email')} autoComplete="email" />
            </Field>
            <Field label="Mật khẩu" error={errors.password}>
              <input type="password" value={form.password} onChange={set('password')} autoComplete={mode.kind === 'login' ? 'current-password' : 'new-password'} />
            </Field>
            {mode.kind === 'register' && (
              <Field label="Nhập lại mật khẩu" error={errors.confirm}>
                <input type="password" value={form.confirm} onChange={set('confirm')} />
              </Field>
            )}
          </>
        )}

        <button type="submit" disabled={busy} style={{ width: '100%', justifyContent: 'center', padding: 11 }}>
          {busy && <span className="spinner" />} {mode.kind === 'login' ? 'Đăng nhập' : mode.kind === 'register' ? 'Đăng ký' : 'Xác minh'}
        </button>
        <div className="row" style={{ justifyContent: 'center' }}>
          {mode.kind === 'login' ? (
            <button type="button" className="link" onClick={() => setMode({ kind: 'register' })}>Chưa có tài khoản? Đăng ký</button>
          ) : (
            <>
              {mode.kind === 'verify' && <button type="button" className="link" onClick={resend}>Gửi lại mã</button>}
              <button type="button" className="link" onClick={() => setMode({ kind: 'login' })}>Quay lại đăng nhập</button>
            </>
          )}
        </div>
      </form>
    </div>
  );
}
