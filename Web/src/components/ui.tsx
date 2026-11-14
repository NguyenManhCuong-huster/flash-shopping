import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { ApiError, mediaUrl } from '../api/client';
import { foodApi } from '../api/endpoints';
import type { Food } from '../api/types';

// ---------------- Toast (kết quả thao tác, NFR06/NFR11) ----------------
interface Toast {
  id: number;
  text: string;
  error?: boolean;
  retry?: () => void;
}
const ToastCtx = createContext<(t: Omit<Toast, 'id'>) => void>(() => {});
export const useToast = () => useContext(ToastCtx);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<Toast[]>([]);
  const push = useCallback((t: Omit<Toast, 'id'>) => {
    const id = Date.now() + Math.random();
    setItems((x) => [...x, { ...t, id }]);
    setTimeout(() => setItems((x) => x.filter((i) => i.id !== id)), t.error ? 6000 : 2500);
  }, []);
  return (
    <ToastCtx.Provider value={push}>
      {children}
      <div className="toasts">
        {items.map((t) => (
          <div key={t.id} className={`toast ${t.error ? 'error' : ''}`}>
            <span style={{ whiteSpace: 'pre-line' }}>{t.text}</span>
            {t.retry && (
              <button className="link light" onClick={t.retry}>
                Thử lại
              </button>
            )}
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  );
}

/** Chạy thao tác ghi: báo thành công chỉ khi backend đã lưu; lỗi mạng có nút thử lại. */
export function useAction() {
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  const run = useCallback(
    async function run<T>(fn: () => Promise<T>, success?: string): Promise<T | undefined> {
      setBusy(true);
      try {
        const r = await fn();
        if (success) toast({ text: success });
        return r;
      } catch (e) {
        const err = e as ApiError;
        toast({ text: err.message ?? String(e), error: true, retry: err.network ? () => run(fn, success) : undefined });
        return undefined;
      } finally {
        setBusy(false);
      }
    },
    [toast],
  );
  return { run, busy };
}

// ---------------- Tải dữ liệu ----------------
export function useLoad<T>(fn: () => Promise<T>, deps: unknown[]) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const reload = useCallback(async () => {
    setLoading(true);
    try {
      setData(await fn());
      setError(null);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  useEffect(() => {
    reload();
  }, [reload]);
  return { data, error, loading, reload, setData };
}

export function Async({ loading, error, empty, emptyText, onRetry, children }: {
  loading: boolean;
  error: string | null;
  empty?: boolean;
  emptyText?: string;
  onRetry: () => void;
  children: ReactNode;
}) {
  if (loading && empty !== false) return <div className="center muted"><span className="spinner" /> Đang tải...</div>;
  if (error) {
    return (
      <div className="center">
        <p className="danger">{error}</p>
        <button onClick={onRetry}>Thử lại</button>
      </div>
    );
  }
  if (empty) return <div className="center muted">{emptyText ?? 'Chưa có dữ liệu'}</div>;
  return <>{children}</>;
}

// ---------------- Modal & xác nhận ----------------
export function Modal({ title, onClose, children, wide }: { title: string; onClose: () => void; children: ReactNode; wide?: boolean }) {
  useEffect(() => {
    const h = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [onClose]);
  return (
    <div className="backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className={`modal ${wide ? 'wide' : ''}`}>
        <div className="modal-head">
          <h3>{title}</h3>
          <button className="icon" onClick={onClose} aria-label="Đóng">✕</button>
        </div>
        {children}
      </div>
    </div>
  );
}

/** Bắt buộc xác nhận trước khi xóa dữ liệu quan trọng (NFR06). */
const ConfirmCtx = createContext<(msg: string, opt?: { title?: string; ok?: string }) => Promise<boolean>>(async () => false);
export const useConfirm = () => useContext(ConfirmCtx);

export function ConfirmProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<{ msg: string; title: string; ok: string; resolve: (v: boolean) => void } | null>(null);
  const ask = useCallback(
    (msg: string, opt?: { title?: string; ok?: string }) =>
      new Promise<boolean>((resolve) => setState({ msg, title: opt?.title ?? 'Xác nhận', ok: opt?.ok ?? 'Xóa', resolve })),
    [],
  );
  const close = (v: boolean) => {
    state?.resolve(v);
    setState(null);
  };
  return (
    <ConfirmCtx.Provider value={ask}>
      {children}
      {state && (
        <Modal title={state.title} onClose={() => close(false)}>
          <p>{state.msg}</p>
          <div className="row end">
            <button className="ghost" onClick={() => close(false)}>Hủy</button>
            <button className="danger-btn" onClick={() => close(true)} autoFocus>{state.ok}</button>
          </div>
        </Modal>
      )}
    </ConfirmCtx.Provider>
  );
}

// ---------------- Thành phần nhỏ ----------------
export function Img({ src, size = 40, round }: { src?: string | null; size?: number; round?: boolean }) {
  const url = mediaUrl(src);
  return url ? (
    <img src={url} width={size} height={size} className={`thumb ${round ? 'round' : ''}`} alt="" />
  ) : (
    <span className={`thumb ph ${round ? 'round' : ''}`} style={{ width: size, height: size }}>🥬</span>
  );
}

export const Pill = ({ children, tone = 'ok' }: { children: ReactNode; tone?: 'ok' | 'warn' | 'bad' | 'info' }) => <span className={`pill ${tone}`}>{children}</span>;

export const toneOf = (status: string) => (status === 'expired' ? 'bad' : status === 'expiring' ? 'warn' : 'ok');

export function Field({ label, error, children, hint }: { label: string; error?: string | null; hint?: string; children: ReactNode }) {
  return (
    <label className="field">
      <span>{label}</span>
      {children}
      {error ? <small className="danger">{error}</small> : hint ? <small className="muted">{hint}</small> : null}
    </label>
  );
}

/** Chọn thực phẩm của nhóm (tìm phía server). */
export function FoodPicker({ value, onChange, placeholder = 'Tìm thực phẩm...' }: { value: Food | null; onChange: (f: Food) => void; placeholder?: string }) {
  const [q, setQ] = useState('');
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<Food[]>([]);
  const timer = useRef<number | undefined>(undefined);
  useEffect(() => {
    if (!open) return;
    clearTimeout(timer.current);
    timer.current = window.setTimeout(async () => {
      try {
        setItems((await foodApi.list(q)).foods);
      } catch {
        setItems([]);
      }
    }, 250);
  }, [q, open]);
  return (
    <div className="picker">
      <input
        value={open ? q : value ? `${value.name} (${value.unit.name})` : ''}
        placeholder={placeholder}
        onFocus={() => {
          setOpen(true);
          setQ('');
        }}
        onBlur={() => setTimeout(() => setOpen(false), 150)}
        onChange={(e) => setQ(e.target.value)}
      />
      {open && (
        <div className="picker-list">
          {items.length === 0 && <div className="muted pad">Không có thực phẩm phù hợp — thêm ở mục Thực phẩm.</div>}
          {items.map((f) => (
            <div key={f.id} className="picker-item" onMouseDown={() => onChange(f)}>
              <Img src={f.imageUrl} size={28} /> {f.name} <span className="muted">· {f.category.name} · {f.unit.name}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export function NeedGroup() {
  return (
    <div className="center card">
      <div style={{ fontSize: 48 }}>👨‍👩‍👧</div>
      <p>Bạn chưa thuộc nhóm gia đình nào. Hãy tạo nhóm hoặc nhờ trưởng nhóm thêm bạn bằng tên người dùng.</p>
      <Link className="btn" to="/group">Tạo / xem nhóm</Link>
    </div>
  );
}
