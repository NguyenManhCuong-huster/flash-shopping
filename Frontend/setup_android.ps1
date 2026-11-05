# Thiết lập phần Android cho dự án (chạy MỘT lần sau khi cài Flutter SDK).
#   cd Frontend
#   powershell -ExecutionPolicy Bypass -File .\setup_android.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error 'Chưa tìm thấy lệnh flutter. Cài Flutter SDK (>= 3.35) và thêm <flutter>\bin vào PATH.'
}

# Sinh thư mục android/ theo đúng phiên bản Flutter đang cài; file đã có (lib/, pubspec.yaml, test/) được giữ nguyên.
flutter create --platforms=android --org vn.edu.hust --project-name di_cho_tien_loi .

$manifest = 'android/app/src/main/AndroidManifest.xml'
$xml = Get-Content $manifest -Raw -Encoding UTF8

# Quyền truy cập mạng cho bản release (bản debug Flutter đã tự thêm)
if ($xml -notmatch 'android.permission.INTERNET') {
  $xml = $xml -replace '(<manifest[^>]*>)', "`$1`n    <uses-permission android:name=`"android.permission.INTERNET`"/>"
}
# Backend dev chạy HTTP trong mạng LAN => cho phép cleartext. Khi triển khai thật dùng HTTPS và bỏ dòng này.
if ($xml -notmatch 'usesCleartextTraffic') {
  $xml = $xml -replace '<application', '<application android:usesCleartextTraffic="true"'
}
$xml = $xml -replace 'android:label="di_cho_tien_loi"', 'android:label="Đi chợ tiện lợi"'
[System.IO.File]::WriteAllText((Resolve-Path $manifest), $xml, (New-Object System.Text.UTF8Encoding($false)))

flutter pub get
Write-Host ''
Write-Host 'Xong. Cắm điện thoại (bật USB debugging) rồi chạy:  flutter run' -ForegroundColor Green
