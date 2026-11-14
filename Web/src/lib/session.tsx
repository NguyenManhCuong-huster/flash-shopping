import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { ApiError, setSessionExpiredHandler, tokens } from '../api/client';
import { authApi, insightApi, userApi } from '../api/endpoints';
import type { User } from '../api/types';

interface Session {
  user: User | null;
  ready: boolean;
  hasGroup: boolean;
  isLeader: boolean;
  isAdmin: boolean;
  unread: number;
  expiredMessage: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refresh: () => Promise<void>;
  setUser: (u: User) => void;
  refreshUnread: () => Promise<void>;
}

const Ctx = createContext<Session>(null as unknown as Session);
export const useSession = () => useContext(Ctx);

/**
 * Phiên đăng nhập + vai trò hiện tại. Giao diện chỉ ẩn thao tác không đủ quyền;
 * backend vẫn kiểm tra token và quyền cho mọi yêu cầu.
 */
export function SessionProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(false);
  const [unread, setUnread] = useState(0);
  const [expiredMessage, setExpired] = useState<string | null>(null);

  const refresh = useCallback(async () => setUser(await userApi.me()), []);

  useEffect(() => {
    setSessionExpiredHandler(() => {
      tokens.clear();
      setUser(null);
      setExpired('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.');
    });
    (async () => {
      if (tokens.refresh) {
        try {
          await refresh();
        } catch (e) {
          if (!(e instanceof ApiError && e.network)) tokens.clear();
        }
      }
      setReady(true);
    })();
  }, [refresh]);

  const refreshUnread = useCallback(async () => {
    try {
      setUnread((await insightApi.notifications(1, true)).unreadCount);
    } catch {
      /* kiểm tra ngầm: bỏ qua lỗi */
    }
  }, []);

  // UC06: kiểm tra thông báo nhắc hạn mỗi phút khi trang đang mở
  useEffect(() => {
    if (!user) return;
    refreshUnread();
    const t = setInterval(refreshUnread, 60_000);
    return () => clearInterval(t);
  }, [user, refreshUnread]);

  const value = useMemo<Session>(
    () => ({
      user,
      ready,
      hasGroup: !!user?.group,
      isLeader: user?.group?.role === 'admin',
      isAdmin: user?.systemRole === 'admin',
      unread,
      expiredMessage,
      login: async (email, password) => {
        await authApi.login(email.trim(), password);
        setExpired(null);
        await refresh();
      },
      logout: async () => {
        await authApi.logout();
        setUser(null);
      },
      refresh,
      setUser,
      refreshUnread,
    }),
    [user, ready, unread, expiredMessage, refresh, refreshUnread],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}
