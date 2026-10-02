# Online DLU

Ứng dụng **không chính thức** cho sinh viên Trường Đại học Đà Lạt: xem thời
khoá biểu, lịch thi, điểm, học phần và điểm rèn luyện ngay trên điện thoại,
đăng nhập bằng đúng tài khoản portal của trường.

Viết bằng Flutter, chạy trên Android, iOS, macOS và web. Giao diện "cozy
neo-brutalism": giấy kem, viền mực đậm, bóng cứng, font Baloo 2.

Đây là dự án cá nhân, không phải sản phẩm của nhà trường và không được nhà
trường bảo trợ. App chỉ **đọc** dữ liệu của chính người đăng nhập, không sửa,
không đăng ký học phần hộ ai.

## Có gì

- Thời khoá biểu theo tháng, thẻ "buổi sắp tới" đếm ngược tới giờ vào lớp
- Thêm lịch học cả tháng vào ứng dụng Lịch của máy (`.ics`, nhắc trước 15 phút)
- Chia sẻ thời khoá biểu dạng ảnh
- Lịch thi từng học kỳ, buổi sắp tới xếp lên đầu
- Điểm từng môn, trung bình học kỳ, GPA tích luỹ; "Thử GPA" để ướm điểm dự kiến
- Kết quả đăng ký học phần, chương trình đào tạo, tiến độ tín chỉ
- Phiếu điểm rèn luyện theo từng tiêu chí
- Tìm trong danh sách môn và học phần, gõ không dấu vẫn ra
- Xem được khi mất mạng: dữ liệu đã xem nằm trong máy, kèm mốc "dữ liệu lúc
  mấy giờ"; kéo xuống là làm mới toàn bộ app

## Chạy thử

```bash
flutter pub get
flutter run                  # máy đang cắm hoặc simulator
flutter run -d macos         # hoặc -d chrome
flutter test                 # 45 test
flutter analyze
```

## Cấu trúc

| File | Việc |
|---|---|
| `lib/portal.dart` | Gọi API portal, cache, lỗi mạng |
| `lib/cache.dart` | Hive cache, TTL 30 phút, mốc dữ liệu, làm mới cả app |
| `lib/paper.dart` | Bảng màu và bộ widget giấy: `PaperBox`, `Pill`, `PullRefresh`… |
| `lib/login.dart` | Đăng nhập, lưu mật khẩu vào Keychain/Keystore |
| `lib/main.dart` | Khung tab, trang chủ, menu |
| `lib/graph.dart` | Thời khoá biểu tháng, buổi sắp tới, chia sẻ ảnh |
| `lib/marks.dart` | Điểm, GPA, thử GPA |
| `lib/exams.dart` · `lib/courses.dart` · `lib/curriculum.dart` | Lịch thi, học phần, chương trình đào tạo |
| `lib/behavior.dart` | Điểm rèn luyện và phiếu chấm |
| `lib/ics.dart` | Xuất `.ics` theo RFC 5545 |
| `lib/data.dart` · `lib/info.dart` · `lib/news.dart` | Tiện ích chung, hồ sơ, thông báo |

Mật khẩu chỉ nằm trong Keychain (iOS/macOS) hoặc Keystore (Android) qua
`flutter_secure_storage`, không bao giờ vào SharedPreferences. Dữ liệu portal
cache trong Hive, đăng xuất là xoá sạch.

`apikey` và `clientid` trong `lib/portal.dart` là khoá client công khai, lấy từ
chính web app của trường — ai mở DevTools trên portal cũng thấy. Chúng không
phải bí mật, nhưng nếu tách repo ra dùng chỗ khác thì nên chuyển sang
`--dart-define`.

## Build bản phát hành

Android cần khoá ký. Keystore nằm sẵn trong `android/app/`, còn mật khẩu thì
không — tạo `android/key.properties` (đã gitignore):

```properties
storePassword=...
keyPassword=...
keyAlias=online-dlu
storeFile=online-dlu.jks
```

```bash
flutter build appbundle --release    # nộp Google Play
flutter build apk --release          # cài tay
flutter build ipa --no-codesign      # iOS, chưa ký
```

Không có `key.properties` thì Gradle tự rơi về debug key, đủ để
`flutter run --release` chạy nhưng không nộp store được.

## Phát hành tự động

Số phiên bản và changelog khai ở **`version.json`** — chỉ sửa đúng file này:

```json
{
  "version": "1.0.8",
  "build": 9,
  "changelog": [
    { "version": "1.0.8", "date": "2026-10-02", "changes": ["Thêm cái này."] }
  ]
}
```

Rồi chạy `python3 tool/version.py sync` để chép sang `pubspec.yaml` và
`lc.json`, và đẩy tag:

```bash
git tag v1.0.8 && git push origin v1.0.8
```

GitHub Actions build cả hai nền tảng, kiểm tag có khớp `version.json` không,
dán changelog vào phần mô tả Release, rồi commit lại `lc.json` kèm kích thước
IPA. App đọc thẳng `version.json` nên màn **Cập nhật** và thẻ *Có gì mới* cũng
ăn theo, không phải gõ lại chỗ nào.

Chi tiết secrets cần khai ở `.github/workflows/release.yml`.

## Cài trên iPhone bằng LiveContainer

[LiveContainer](https://github.com/khanhduytran0/LiveContainer) chạy app iOS
bên trong nó, nên chỉ phải ký lại LiveContainer mỗi tuần thay vì ký lại từng
app, và không tốn slot trong 3 app mà chứng chỉ miễn phí cho phép.

Trong LiveContainer, thêm nguồn:

```
https://raw.githubusercontent.com/dopaemon/online-dlu/main/lc.json
```

`lc.json` trỏ thẳng vào bản mới nhất ở Releases, nên phát hành tag mới là máy
hiện nút cập nhật — workflow tự chép số phiên bản vào file đó sau mỗi lần build
(`tool/version.py sync`).

Nguồn này chỉ hoạt động khi repo để **public**; repo private thì cả
`raw.githubusercontent.com` lẫn file trong Releases đều đòi đăng nhập.

Không dùng LiveContainer thì tải thẳng `.ipa` ở Releases rồi ký bằng Sideloadly
hoặc AltStore như thường.

## Nền tảng tối thiểu

Android 7.0 (API 24) và iOS 15 — đều là mức thấp nhất Flutter còn cho phép.

## Giấy phép

MIT, xem `LICENSE`.
