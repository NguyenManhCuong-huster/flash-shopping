# Đi chợ tiện lợi – Bản web

React 19 + TypeScript + Vite. Cùng backend và cùng chức năng với app Android; chat trợ lý AI hiện chữ dần qua SSE.

## Chạy (cùng backend, bằng Docker)

```bash
cd ../Backend
docker compose up -d --build
```

Mở **http://localhost:8081** (đổi cổng bằng `WEB_HOST_PORT`). Nginx phục vụ bản build và chuyển `/api/*` sang API,
nên không cần CORS. Mã OTP khi đăng ký xem tại http://localhost:8025. Admin: `admin@dicho.local` / `Admin@123`.

## Phát triển (không cần build lại Docker)

```bash
npm install
npm run dev        # http://localhost:5173, /api -> http://localhost:3001 (API trong Docker)
npm run build      # kiểm tra kiểu + build ra dist/
```

## Cấu trúc

```
src/api/client.ts      fetch + Bearer token, tự làm mới token (00011), lỗi mạng -> nút "Thử lại", đọc SSE
src/api/endpoints.ts   một hàm cho mỗi API backend
src/lib/session.tsx    phiên đăng nhập, vai trò (trưởng nhóm / admin), đếm thông báo chưa đọc mỗi phút
src/components/ui.tsx  toast, hộp thoại xác nhận xóa, trạng thái tải/lỗi/rỗng, chọn thực phẩm
src/pages/             Auth, Dashboard, Shopping, Fridge, Meals, Recipes, Foods, Stats, Account, Notifications, Ai, Admin
```

Giao diện chỉ ẩn thao tác không đủ quyền; backend vẫn kiểm tra token và quyền cho mọi yêu cầu.
Token lưu trong `localStorage` của trình duyệt (bản demo). Khi triển khai thật nên dùng HTTPS.
