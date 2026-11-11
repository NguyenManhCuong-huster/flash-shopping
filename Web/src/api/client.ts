/** HTTP client: gắn Bearer token, tự làm mới token khi hết hạn (00011), chuẩn hóa lỗi thành ApiError. */

export const API_BASE: string = import.meta.env.VITE_API_BASE ?? '/api';

export class ApiError extends Error {
  constructor(
    public code: string,
    message: string,
    public status = 0,
    public data: any = null,
    /** Mất kết nối: thao tác CHƯA được lưu, cho phép thử lại (NFR11) */
    public network = false,
  ) {
    super(message);
  }
}

export interface ApiResult<T> {
  code: string;
  message: string;
  data: T;
}

const ACCESS = 'dc_access';
const REFRESH = 'dc_refresh';

export const tokens = {
  get access() {
    return localStorage.getItem(ACCESS);
  },
  get refresh() {
    return localStorage.getItem(REFRESH);
  },
  save(access: string, refresh: string) {
    localStorage.setItem(ACCESS, access);
    localStorage.setItem(REFRESH, refresh);
  },
  clear() {
    localStorage.removeItem(ACCESS);
    localStorage.removeItem(REFRESH);
  },
};

let onExpired: () => void = () => {};
export const setSessionExpiredHandler = (fn: () => void) => {
  onExpired = fn;
};

let refreshing: Promise<boolean> | null = null;

/** Refresh token chỉ dùng được một lần => mọi request đang chờ dùng chung một lần làm mới. */
function refreshTokens(): Promise<boolean> {
  refreshing ??= (async () => {
    try {
      const rt = tokens.refresh;
      if (!rt) return false;
      const res = await fetch(`${API_BASE}/user/refresh-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: rt }),
      });
      if (!res.ok) {
        tokens.clear();
        return false;
      }
      const j = await res.json();
      tokens.save(j.data.accessToken, j.data.refreshToken);
      return true;
    } catch {
      return false;
    } finally {
      refreshing = null;
    }
  })();
  return refreshing;
}

type Query = Record<string, string | number | boolean | null | undefined>;

interface Options {
  body?: unknown;
  query?: Query;
  headers?: Record<string, string>;
}

function buildUrl(path: string, query?: Query) {
  const qs = new URLSearchParams();
  for (const [k, v] of Object.entries(query ?? {})) {
    if (v !== undefined && v !== null && v !== '') qs.set(k, String(v));
  }
  const s = qs.toString();
  return `${API_BASE}${path}${s ? `?${s}` : ''}`;
}

async function rawFetch(method: string, path: string, opt: Options) {
  const isForm = opt.body instanceof FormData;
  const headers: Record<string, string> = { ...(opt.headers ?? {}) };
  if (tokens.access) headers.Authorization = `Bearer ${tokens.access}`;
  if (opt.body !== undefined && !isForm) headers['Content-Type'] = 'application/json';
  try {
    return await fetch(buildUrl(path, opt.query), {
      method,
      headers,
      body: opt.body === undefined ? undefined : isForm ? (opt.body as FormData) : JSON.stringify(opt.body),
    });
  } catch {
    throw new ApiError('NETWORK', 'Không kết nối được máy chủ. Thao tác chưa được lưu, vui lòng kiểm tra mạng và thử lại.', 0, null, true);
  }
}

export async function request<T = any>(method: string, path: string, opt: Options = {}): Promise<ApiResult<T>> {
  let res = await rawFetch(method, path, opt);
  let body = await res.json().catch(() => ({}));
  if (res.status === 401 && tokens.access && ['00011', '00012'].includes(body.code)) {
    if (await refreshTokens()) {
      res = await rawFetch(method, path, opt);
      body = await res.json().catch(() => ({}));
    } else {
      onExpired();
    }
  }
  if (!res.ok) throw new ApiError(body.code ?? String(res.status), body.message ?? `Lỗi máy chủ (${res.status})`, res.status, body.data);
  return body as ApiResult<T>;
}

export const http = {
  get: <T = any>(path: string, query?: Query) => request<T>('GET', path, { query }).then((r) => r.data),
  post: <T = any>(path: string, body?: unknown, headers?: Record<string, string>) => request<T>('POST', path, { body, headers }),
  put: <T = any>(path: string, body?: unknown) => request<T>('PUT', path, { body }),
  del: <T = any>(path: string, body?: unknown) => request<T>('DELETE', path, { body }),
};

/** Ảnh server trả dạng "/uploads/..." -> đi qua proxy /api. */
export const mediaUrl = (p?: string | null) => (!p ? null : p.startsWith('http') ? p : `${API_BASE}${p}`);

/**
 * POST trả về text/event-stream (chat AI). Gọi onEvent cho từng sự kiện SSE.
 * Lỗi trước khi stream bắt đầu (401, 4xx) được ném ra như request thường.
 */
export async function postStream(path: string, body: unknown, onEvent: (event: string, data: any) => void, signal?: AbortSignal) {
  const send = () =>
    fetch(buildUrl(path), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(tokens.access ? { Authorization: `Bearer ${tokens.access}` } : {}) },
      body: JSON.stringify(body),
      signal,
    });
  let res: Response;
  try {
    res = await send();
    if (res.status === 401 && (await refreshTokens())) res = await send();
  } catch (e) {
    if ((e as Error).name === 'AbortError') throw e;
    throw new ApiError('NETWORK', 'Không kết nối được máy chủ.', 0, null, true);
  }
  if (!res.ok || !(res.headers.get('content-type') ?? '').includes('event-stream')) {
    const j = await res.json().catch(() => ({}));
    if (res.status === 401) onExpired();
    throw new ApiError(j.code ?? String(res.status), j.message ?? 'Lỗi máy chủ', res.status, j.data);
  }
  const reader = res.body!.getReader();
  const decoder = new TextDecoder();
  let buf = '';
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buf += decoder.decode(value, { stream: true });
    let idx;
    while ((idx = buf.indexOf('\n\n')) >= 0) {
      const chunk = buf.slice(0, idx);
      buf = buf.slice(idx + 2);
      const ev = /^event: (.+)$/m.exec(chunk)?.[1] ?? 'message';
      const data = /^data: (.*)$/m.exec(chunk)?.[1];
      if (data) onEvent(ev, JSON.parse(data));
    }
  }
}
