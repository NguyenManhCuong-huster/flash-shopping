import { useNavigate } from 'react-router-dom';
import { insightApi } from '../api/endpoints';
import { Async, useAction, useLoad } from '../components/ui';
import { relativeTime } from '../lib/format';
import { useSession } from '../lib/session';

/** UC06 - hộp thư nhắc hạn sử dụng; bấm thông báo => mở chi tiết thực phẩm. */
export function NotificationsPage() {
  const s = useSession();
  const nav = useNavigate();
  const { run } = useAction();
  const { data, loading, error, reload } = useLoad(() => insightApi.notifications(), []);
  const items = data?.notifications ?? [];
  return (
    <>
      <div className="page-head">
        <h1>Thông báo</h1>
        <button className="ghost" disabled={!items.some((n) => !n.read)} onClick={async () => {
          await run(() => insightApi.markRead());
          await s.refreshUnread();
          reload();
        }}>Đánh dấu đã đọc tất cả</button>
      </div>
      <Async loading={loading} error={error} empty={!items.length} onRetry={reload} emptyText="Chưa có thông báo. Ứng dụng sẽ nhắc trước khi thực phẩm hết hạn 3 ngày.">
        <div className="list">
          {items.map((n) => (
            <div key={n.id} className="item click" style={{ background: n.read ? undefined : 'var(--primary-soft)' }} onClick={async () => {
              if (!n.read) {
                await insightApi.markRead([n.id]).catch(() => {});
                s.refreshUnread();
              }
              if (n.data.fridgeItemId) nav(`/fridge/${n.data.fridgeItemId}`);
              else reload();
            }}>
              <span style={{ fontSize: 20 }}>{n.type === 'food_expired' ? '⛔' : '⏰'}</span>
              <div className="grow">
                <div className="title" style={{ fontWeight: n.read ? 'normal' : 'bold' }}>{n.title}</div>
                <div className="sub">{n.body}</div>
                <div className="sub">{relativeTime(n.createdAt)}</div>
              </div>
            </div>
          ))}
        </div>
      </Async>
    </>
  );
}
