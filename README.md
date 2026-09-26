# TKB — thời khoá biểu cá nhân

Flutter app (Android, iOS, macOS, web). Giao diện "cozy neo-brutalism" mượn từ codex-resets.com:
giấy kem, viền mực 2px, shadow cứng, font Baloo 2.

## Chạy

```bash
flutter run                       # điện thoại đang cắm / simulator
flutter run -d macos              # hoặc -d chrome
flutter test            # test model + logic buổi học tiếp theo
```

## Cấu trúc

- `lib/data.dart` — `Slot` (buổi học lặp hàng tuần), `Task` (việc cần làm), `Store`
  (lưu tất cả vào 1 key JSON trong SharedPreferences).
- `lib/paper.dart` — bảng màu + `PaperBox` / `PaperButton` / `Pill` / nền chấm.
- `lib/main.dart` — màn hình chính và 2 dialog thêm/sửa.

Dưới 900px bề ngang (điện thoại) các ngày xếp dọc và ngày trống được ẩn;
rộng hơn thì hiện lưới 7 cột.

Dữ liệu nhập tay, lưu local trên máy. Chưa có đồng bộ, chưa nối portal DLU.
