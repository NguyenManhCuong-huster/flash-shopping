import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import { useSession } from './lib/session';
import { AuthPage } from './pages/Auth';
import { Dashboard } from './pages/Dashboard';
import { ShoppingPage, ShoppingDetail } from './pages/Shopping';
import { FridgePage, FridgeItemPage } from './pages/Fridge';
import { MealsPage } from './pages/Meals';
import { RecipesPage, RecipeDetail, SuggestionsPage } from './pages/Recipes';
import { FoodsPage } from './pages/Foods';
import { StatsPage } from './pages/Stats';
import { GroupPage, ProfilePage } from './pages/Account';
import { NotificationsPage } from './pages/Notifications';
import { AiPage } from './pages/Ai';
import { AdminPage } from './pages/Admin';

const MAIN = [
  { to: '/', icon: '🏠', label: 'Trang chủ' },
  { to: '/shopping', icon: '🛒', label: 'Mua sắm' },
  { to: '/fridge', icon: '🧊', label: 'Tủ lạnh' },
  { to: '/meals', icon: '🍽️', label: 'Bữa ăn' },
];
const MORE = [
  { to: '/recipes', icon: '📖', label: 'Công thức' },
  { to: '/suggestions', icon: '✨', label: 'Gợi ý món' },
  { to: '/foods', icon: '🥕', label: 'Thực phẩm' },
  { to: '/stats', icon: '📊', label: 'Thống kê' },
  { to: '/ai', icon: '🤖', label: 'Trợ lý AI' },
  { to: '/group', icon: '👨‍👩‍👧', label: 'Nhóm gia đình' },
  { to: '/profile', icon: '👤', label: 'Hồ sơ' },
];

export default function App() {
  const s = useSession();
  if (!s.ready) return <div className="center muted"><span className="spinner" /> Đang tải...</div>;
  if (!s.user) return <AuthPage />;

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="brand">🧺 Đi chợ tiện lợi</div>
        <nav className="nav">
          {MAIN.map((n) => (
            <NavLink key={n.to} to={n.to} end={n.to === '/'}>{n.icon} {n.label}</NavLink>
          ))}
          <NavLink to="/notifications">🔔 Thông báo {s.unread > 0 && <span className="badge">{s.unread}</span>}</NavLink>
          <div className="sep" />
          {MORE.map((n) => (
            <NavLink key={n.to} to={n.to}>{n.icon} {n.label}</NavLink>
          ))}
          {s.isAdmin && <NavLink to="/admin">🛡️ Quản trị</NavLink>}
          <div className="sep" />
          <div className="pad muted" style={{ fontSize: 13 }}>
            {s.user.name}
            <br />
            {s.user.group ? `${s.user.group.name} · ${s.isLeader ? 'Trưởng nhóm' : 'Thành viên'}` : 'Chưa có nhóm'}
          </div>
          <a href="#" onClick={(e) => { e.preventDefault(); s.logout(); }}>🚪 Đăng xuất</a>
        </nav>
      </aside>

      <main className="main">
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/more" element={<Dashboard />} />
          <Route path="/shopping" element={<ShoppingPage />} />
          <Route path="/shopping/:id" element={<ShoppingDetail />} />
          <Route path="/fridge" element={<FridgePage />} />
          <Route path="/fridge/:id" element={<FridgeItemPage />} />
          <Route path="/meals" element={<MealsPage />} />
          <Route path="/recipes" element={<RecipesPage />} />
          <Route path="/recipes/:id" element={<RecipeDetail />} />
          <Route path="/suggestions" element={<SuggestionsPage />} />
          <Route path="/foods" element={<FoodsPage />} />
          <Route path="/stats" element={<StatsPage />} />
          <Route path="/group" element={<GroupPage />} />
          <Route path="/profile" element={<ProfilePage />} />
          <Route path="/notifications" element={<NotificationsPage />} />
          <Route path="/ai" element={<AiPage />} />
          <Route path="/ai/:id" element={<AiPage />} />
          {s.isAdmin && <Route path="/admin" element={<AdminPage />} />}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>

      {/* Điện thoại: thanh dưới - khu vực trọng yếu trong 1 chạm (NFR04) */}
      <nav className="bottom-nav">
        {MAIN.map((n) => (
          <NavLink key={n.to} to={n.to} end={n.to === '/'}><span className="ic">{n.icon}</span>{n.label}</NavLink>
        ))}
        <NavLink to="/more"><span className="ic">☰</span>Thêm</NavLink>
      </nav>
      <Routes>
        <Route path="/more" element={<MoreMenu />} />
        <Route path="*" element={null} />
      </Routes>
    </div>
  );
}

/** Menu "Thêm" cho màn hình hẹp. */
function MoreMenu() {
  const s = useSession();
  return (
    <div className="backdrop" style={{ alignItems: 'flex-end' }}>
      <div className="modal">
        <div className="list">
          {[...MORE, { to: '/notifications', icon: '🔔', label: `Thông báo${s.unread ? ` (${s.unread})` : ''}` }, ...(s.isAdmin ? [{ to: '/admin', icon: '🛡️', label: 'Quản trị' }] : [])].map((n) => (
            <NavLink key={n.to} to={n.to} className="item click">{n.icon} {n.label}</NavLink>
          ))}
          <a className="item click" href="#" onClick={(e) => { e.preventDefault(); s.logout(); }}>🚪 Đăng xuất</a>
        </div>
        <div className="row end"><NavLink to="/" className="btn">Đóng</NavLink></div>
      </div>
    </div>
  );
}
