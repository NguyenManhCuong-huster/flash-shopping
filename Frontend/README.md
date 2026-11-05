# Đi chợ tiện lợi – Ứng dụng Flutter (Android)

Hiện thực Chương 5 của báo cáo: kiến trúc 3 tầng, tầng trình bày theo MVVM (`provider` + `ChangeNotifier`).

```
lib/
  main.dart                 Khởi động, chọn màn hình theo trạng thái phiên
  bootstrap/                Lắp ráp phụ thuộc (ApiClient -> Repository -> Service), không chứa nghiệp vụ
  presentation/<chức năng>/ View + ViewModel (auth, home, group, profile, food, fridge, shopping, meal, recipe, stats, notification, admin, ai)
  presentation/shared/      Theme (NFR01), định dạng dd/MM/yyyy (NFR02), widget trạng thái tải/lỗi/rỗng, xác nhận xóa
  application/              Service điều phối ca sử dụng, SessionService (vai trò), validation
  data/remote|local|models|repositories   ApiClient (Dio, tự làm mới token), TokenStore (EncryptedSharedPreferences), DTO
```

Hướng phụ thuộc một chiều: View/ViewModel chỉ gọi Service; Service gọi Repository; Repository gọi ApiClient.

## Yêu cầu

- Flutter SDK **3.35 trở lên** (Dart ≥ 3.9) – `flutter --version`
- Android SDK (đã có trên máy), điện thoại Android bật **Tùy chọn nhà phát triển → Gỡ lỗi USB**
- Backend đang chạy (`cd ../Backend && docker compose up -d`)

## Thiết lập lần đầu

Thư mục `android/` được sinh bởi chính Flutter SDK trên máy bạn để khớp phiên bản Gradle:

```powershell
cd Frontend
powershell -ExecutionPolicy Bypass -File .\setup_android.ps1
```

Script chạy `flutter create` (chỉ thêm file còn thiếu, không ghi đè `lib/`), thêm quyền INTERNET + cho phép HTTP
trong mạng nội bộ vào `AndroidManifest.xml`, rồi `flutter pub get`.

## Chạy trên điện thoại thật

**Cách 1 – cáp USB (khuyên dùng):** điện thoại gọi `localhost:3001`, adb chuyển về máy tính.

```powershell
adb devices                          # thấy điện thoại ở trạng thái "device"
adb reverse tcp:3001 tcp:3001        # chạy lại mỗi lần cắm lại cáp
flutter run                          # hoặc: flutter run --release
```

**Cách 2 – Wi‑Fi:** điện thoại và máy tính cùng mạng. Ở màn hình đăng nhập bấm dòng "Máy chủ: ..." và nhập
`http://192.168.0.101:3001` (IP LAN hiện tại của máy tính – xem lại bằng `ipconfig`). Nếu không kết nối được,
mở cổng trên tường lửa Windows (PowerShell quyền Administrator):

```powershell
New-NetFirewallRule -DisplayName "Di cho API 3001" -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow
```

**Cài file APK:** `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
Đặt sẵn địa chỉ máy chủ khi build: `flutter build apk --release --dart-define=API_BASE_URL=http://192.168.0.101:3001`.

## Dùng thử

1. Đăng ký → mở http://localhost:8025 (Mailpit) trên máy tính để lấy mã OTP → xác minh → đăng nhập.
2. Thêm → Hồ sơ: đặt **tên người dùng**; Thêm → Nhóm gia đình: tạo nhóm, thêm thành viên bằng tên người dùng.
3. Thêm → Thực phẩm: khai báo thực phẩm (danh mục, đơn vị, ảnh).
4. Mua sắm: trưởng nhóm tạo danh sách, giao người mua, thêm món → người được giao bấm **Xác nhận đã mua**, nhập
   số lượng thực mua + hạn dùng → món tự vào tủ lạnh.
5. Tủ lạnh: ghi nhận "Đã dùng" / "Bỏ đi"; món còn ≤ 3 ngày sẽ có thông báo nhắc hạn (chuông ở Trang chủ).
6. Bữa ăn: lên bữa theo công thức → Kiểm tra nguyên liệu → thêm phần thiếu vào danh sách mua.
7. Quản trị (`admin@dicho.local` / `Admin@123`): Thêm → Quản trị hệ thống.

## Kiểm thử

```powershell
flutter analyze
flutter test
```

## Ghi chú

- Thông báo nhắc hạn: backend gửi push qua FCM khi được cấu hình. Bản app này chưa tích hợp Firebase
  (cần `google-services.json` của dự án Firebase riêng), nên app tự kiểm tra hộp thư mỗi phút khi đang mở
  và mỗi lần mở lại app, hiện badge + thông báo trong app.
- Xác nhận mua dùng khóa chống lặp: bấm "Thử lại" sau lỗi mạng không làm cộng tồn kho hai lần.
- Các thao tác chỉ dành cho trưởng nhóm được ẩn khỏi giao diện thành viên; backend vẫn kiểm tra quyền mọi yêu cầu.
- Phông Arial (NFR01): Android không có sẵn Arial nên hiển thị bằng phông mặc định tương đương.
