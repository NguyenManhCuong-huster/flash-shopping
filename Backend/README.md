# Đi chợ tiện lợi – Backend

Node.js 22 (Express 5) + PostgreSQL 16, chạy bằng Docker Compose. Hiện thực theo Chương 4 của báo cáo
(lược đồ CSDL Bảng 8–28, danh sách API Bảng 30, mã phản hồi Bảng 29, mô-đun AI Agent).

## Chạy

```bash
cp .env.example .env        # sửa JWT_ACCESS_SECRET, ADMIN_PASSWORD, (tùy chọn) AI_API_KEY
docker compose up -d --build
curl http://localhost:3001/health
```

| Dịch vụ | Địa chỉ trên máy | Ghi chú |
|---|---|---|
| API | `http://localhost:3001` | đổi bằng `API_HOST_PORT` |
| PostgreSQL | `localhost:5433` (dicho/dicho) | đổi bằng `DB_HOST_PORT` |
| Mailpit (hộp thư OTP) | `http://localhost:8025` | mọi email xác minh đi vào đây |

Migration (`db/migrations/*.sql`) tự chạy khi khởi động. Tài khoản quản trị hệ thống được tạo từ
`ADMIN_EMAIL` / `ADMIN_PASSWORD` (mặc định `admin@dicho.local` / `Admin@123`).

Điện thoại thật: cắm USB và chạy `adb reverse tcp:3001 tcp:3001` (app dùng `http://localhost:3001`), hoặc qua Wi-Fi dùng `http://<IP LAN máy tính>:3001`. Máy ảo: `http://10.0.2.2:3001`.

## Kiểm thử

```bash
node scripts/smoke.mjs          # 121 kịch bản: nghiệp vụ, phân quyền, cách ly nhóm, giao dịch, chống lặp
node scripts/ai-mock-test.mjs --all   # vòng lặp AI Agent với LLM giả lập (không tốn phí API)
```

`smoke.mjs` cần stack đang chạy (đọc OTP thật từ Mailpit). `ai-mock-test.mjs --all` tự chạy một API phụ ở cổng 3002 trỏ tới mock LLM.

## Kiến trúc

```
src/
  routes.js, modules/ai/ai.routes.js   Controller mỏng: lấy tham số -> gọi Service
  modules/<nghiệp vụ>/*.service.js     Service dùng chung cho REST và AI (validation, quyền, mã phản hồi)
  common/permissions.js                requireMember / requireLeader / requireSystemAdmin
  middlewares/auth.js                  Bearer JWT -> req.ctx (userId, groupId, groupRole lấy từ CSDL)
  modules/notification/expiry.job.js   Tác vụ nhắc hạn + gửi push (FCM hoặc log)
  modules/ai/                          Tool Registry, Guard, Orchestrator, LLM Gateway, Suggestion Worker
```

- **Xác thực:** access JWT 15 phút + refresh token xoay vòng (chỉ lưu hash, dùng lại token cũ => thu hồi mọi phiên).
  Đăng xuất / đổi mật khẩu / bị khóa => access token của phiên đó mất hiệu lực ngay.
- **Phân quyền:** `group_id` và vai trò luôn lấy từ token + `group_members`, không bao giờ lấy từ tham số (NFR13).
  Dữ liệu nhóm khác trả "không tìm thấy" thay vì lộ sự tồn tại.
- **Giao dịch:** xác nhận mua và ghi nhận tiêu thụ chạy trong một giao dịch, khóa dòng `FOR UPDATE` (NFR09).
- Mọi thao tác ghi được ghi `audit_logs` (nguồn `app` / `ai` / `system`).

## API bổ sung so với báo cáo

Báo cáo ghi rõ ở UC04, UC05, UC06 rằng "cần bổ sung hợp đồng API"; các API dưới đây lấp các chỗ đó.
Mã phản hồi mới nằm trong dải `005xx` (`src/common/codes.js`).

| API | Mục đích |
|---|---|
| `POST shopping/purchase/` + header `Idempotency-Key` | UC04: xác nhận mua nhiều mục, đưa vào tủ lạnh, ghi lịch sử – một giao dịch, chống lặp |
| `GET shopping/:listId/` | Chi tiết một danh sách |
| `POST fridge/consume/` `{itemId, quantity, type: consume|discard, version}` | UC05: trừ tồn + lịch sử trong giao dịch; `version` phát hiện cập nhật đồng thời (00523) |
| `GET fridge/item/:itemId/` | Mở chi tiết từ thông báo (UC06 bước 6) |
| `GET recipe/suggest/`, `GET recipe/:id/` | UC09 gợi ý món từ tủ lạnh; chi tiết công thức |
| `GET meal/ingredients/`, `POST meal/missing-to-shopping/` | UC08: nguyên liệu cần/có/thiếu; thêm phần thiếu vào danh sách (extend) |
| `GET stats/`, `GET stats/events/` | UC10: báo cáo + lịch sử biến động kho (phân trang ≤ 50) |
| `GET notification/`, `PUT notification/read/`, `POST/DELETE user/device/` | UC06: hộp thư, đăng ký token FCM |
| `POST user/group/leave/`, `PUT user/group/leader/`, `PUT user/group/` | Rời nhóm, chuyển trưởng nhóm, đổi tên nhóm |
| `GET/PUT admin/users/` | UC11: khóa/mở khóa, cấp quyền quản trị |
| `POST ai/suggestion/refresh/` | Trưởng nhóm chạy Suggestion Worker ngay (tiện demo) |

## Quyết định thiết kế khác với báo cáo (và lý do)

| Báo cáo | Hiện thực | Lý do |
|---|---|---|
| `foods.name` UNIQUE toàn hệ thống | UNIQUE theo `(group_id, name)` | Hai gia đình đều có "Trứng gà". Báo cáo nêu phương án này kèm điều kiện "mọi API tra tên phải có phạm vi nhóm" – đã đáp ứng vì nhóm lấy từ token. |
| Công thức chỉ tham chiếu 1 food | Thêm bảng `recipe_ingredients` (nguyên liệu phụ, định lượng) | UC08/UC09 cần "nguyên liệu thiếu"; `recipes.food_id` vẫn là nguyên liệu chính. |
| `shopping_lists.assigned_user_id` NOT NULL | Cho phép NULL | UC03 ghi "người được giao nếu có"; thành viên rời nhóm thì danh sách tự về "chưa giao". |
| Bảng thiếu trạng thái mua, vị trí tủ lạnh | Thêm `shopping_tasks.status/bought_*`, `fridge_items.location/version`, `stock_events`, `idempotency_keys`, `notifications`, `device_tokens` | Cần cho UC04, UC05, UC06, UC10. |
| AI: "20 tin gần nhất + summary"; lọc tool theo vai trò | Gửi toàn bộ lịch sử (append-only) + compaction phía server; danh sách tool cố định, Guard/Service chặn khi thực thi | Sửa/cắt lịch sử hoặc đổi system prompt/tool giữa các lượt làm mất prompt cache và làm vô hiệu "thinking" của model. Thời gian, vai trò, màn hình hiện tại được gắn vào tin nhắn người dùng. |
| `ai_messages.content` JSONB | JSON | JSONB sắp xếp lại khóa, khiến lịch sử gửi lại không còn giống từng byte (phát hiện bởi `ai-mock-test.mjs`). |
| Ngôn ngữ `tr-en` (mã 00079) | `vi`, `en` | |

## Push notification (UC06)

Tác vụ chạy theo `EXPIRY_JOB_CRON` (mặc định 30 phút) và ngay sau khi nhập kho: tạo thông báo cho mọi thành viên với
khóa chống trùng `(người nhận, loại, mục + mốc hạn)`, rồi gửi qua `FCM_PROJECT_ID` + `FCM_SERVICE_ACCOUNT_FILE`.
Token hết hiệu lực bị vô hiệu hóa; lỗi tạm thời thử lại tối đa `PUSH_RETRY_LIMIT` lần (giãn cách 2^n phút).
Không cấu hình FCM thì chỉ ghi log và lưu hộp thư (ứng dụng tự kiểm tra định kỳ).

## Trợ lý AI

Đặt `AI_API_KEY` (Claude API) để bật chat. Model mặc định `claude-opus-5-5`, chỉnh bằng `AI_MODEL`, `AI_EFFORT`.
Thao tác đọc tự chạy; tạo/sửa chờ xác nhận (trừ khi người dùng bật tự thực thi); xóa luôn chờ xác nhận; hành động
chờ quá 15 phút tự hết hạn. Không cấu hình khóa API thì `ai/chat/` trả `00413`, các phần còn lại vẫn hoạt động.

**HTTPS (NFR12):** khi triển khai thật, đặt API sau reverse proxy có TLS (Nginx/Caddy) và đổi `JWT_ACCESS_SECRET`.
