import 'package:flutter/foundation.dart';

import 'settings.dart';

/// Một dòng nhật ký: lúc nào, chỗ nào, chuyện gì.
typedef DongLog = ({DateTime luc, String nguon, String viec});

/// Nhật ký verbose của chế độ nhà phát triển: mọi lượt gọi mạng, mọi nhịp
/// làm mới và mọi bước đi của app đều rơi vào đây.
///
/// **Không bao giờ ghi query string hay thân request.** Lượt đăng nhập mang
/// mật khẩu đi trong thân, mà URL của LMS thì mang token phiên trong query —
/// vào sổ là nó nằm trong máy và đi theo mọi ảnh chụp màn hình. Chỉ ghi
/// phương thức, host + path, mã trả về, kích thước và thời gian.
class NhatKy {
  /// Giữ chừng này dòng gần nhất; cũ hơn thì rụng. Sổ chỉ để xem tại chỗ,
  /// không phải chỗ lưu trữ, nên không ghi xuống đĩa.
  static const gioiHan = 500;

  /// Tắt là không tốn gì: mọi [ghi] thoát ngay ở dòng đầu. Để dạng notifier
  /// vì bật/tắt trong Cài đặt phải làm thẻ Log trên Trang chủ hiện/biến ngay,
  /// chứ không đợi mở lại app.
  static final batN = ValueNotifier(false);
  static bool get bat => batN.value;
  static set bat(bool v) => batN.value = v;

  /// Danh sách đổi là màn Log vẽ lại — mới nhất nằm đầu.
  static final dong = ValueNotifier<List<DongLog>>(const []);

  /// Đọc cờ từ cài đặt. Gọi lúc mở app và mỗi lần bật/tắt trong Cài đặt.
  static Future<void> dongBo() async {
    bat = await Settings.devMode();
    if (!bat) xoa();
  }

  static void ghi(String nguon, String viec) {
    if (!bat) return;
    final moi = [
      (luc: DateTime.now(), nguon: nguon, viec: viec),
      ...dong.value,
    ];
    dong.value = moi.length > gioiHan ? moi.sublist(0, gioiHan) : moi;
  }

  static void xoa() => dong.value = const [];

  /// Địa chỉ đã cắt sạch query — dùng cho mọi dòng log có URL.
  static String diaChi(Uri u) => '${u.host}${u.path}';

  /// Gói một lượt gọi mạng: ghi lúc đi, lúc về kèm thời gian và cỡ dữ liệu.
  static Future<T> goi<T>(
    String nguon,
    String nhan,
    Future<T> Function() viec, {
    int Function(T)? co,
  }) async {
    if (!bat) return viec();
    final batDau = DateTime.now();
    ghi(nguon, '→ $nhan');
    try {
      final ket = await viec();
      final ms = DateTime.now().difference(batDau).inMilliseconds;
      final kich = co == null ? '' : ', ${co(ket)} B';
      ghi(nguon, '← $nhan (${ms}ms$kich)');
      return ket;
    } catch (e) {
      final ms = DateTime.now().difference(batDau).inMilliseconds;
      ghi(nguon, '✗ $nhan (${ms}ms): $e');
      rethrow;
    }
  }
}

/// Bật/tắt chế độ nhà phát triển ở một chỗ, để cờ trong [NhatKy] không lệch
/// với cờ trong SQLite.
Future<void> datDevMode(bool v) async {
  await Settings.datDevMode(v);
  NhatKy.bat = v;
  NhatKy.ghi('app', v ? 'bật chế độ nhà phát triển' : 'tắt');
  if (!v) NhatKy.xoa();
}
