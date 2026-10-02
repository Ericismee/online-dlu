import 'dart:async';
import 'dart:convert';

import 'db.dart';

/// Cache JSON của portal trong SQLite ([Db]): mở app là có dữ liệu ngay, hết
/// hạn thì làm mới ngầm.
class Cache {
  /// Cũ hơn ngần này thì nạp lại ngầm, còn hiển thị vẫn lấy từ cache.
  static const ttl = Duration(minutes: 30);

  static const _nhom = nhomCache;

  /// Đọc đồng bộ nên giữ một bản trong RAM; SQLite là nơi lưu thật.
  static final _ram = <String, (dynamic, DateTime)>{};

  /// Bật trong lúc kéo xuống làm mới: bỏ qua cache, gọi thẳng portal.
  /// ponytail: cờ toàn cục vì mỗi lần chỉ có một lượt làm mới.
  static bool bypass = false;

  /// Lượt nạp sẵn chạy trong zone mang cờ này: nó bỏ qua cache để lấy số
  /// mới, còn màn đang mở vẫn đọc cache như thường, không bị kéo theo.
  static const forceKey = #dluForceFetch;

  static bool get forced => Zone.current[forceKey] == true;

  /// Màn hình đang mở tự đăng ký hàm nạp lại, kéo xuống là gọi hết.
  static final refreshers = <Future<void> Function()>{};

  /// Kéo làm mới lúc nào. Số ghi trước mốc này coi như phải lấy lại, kể cả
  /// của màn chưa mở — kéo ở đâu cũng là làm mới cả app.
  static DateTime? refreshedAt;

  static bool invalidated(DateTime at) =>
      refreshedAt != null && at.isBefore(refreshedAt!);

  /// Nạp lại mọi màn đang mở nhưng vẫn xài cache: màn nào trống (nạp hỏng,
  /// hoặc dữ liệu vừa được nạp sẵn xong) thì có số ngay mà không gọi portal
  /// thêm lần nào.
  static Future<void> reloadAll() =>
      Future.wait(refreshers.map((f) => f())).then((_) {});

  /// Nạp lại mọi màn đang mở, data cũ vẫn hiện cho tới khi có data mới.
  static Future<void> refreshAll() async {
    refreshedAt = DateTime.now();
    bypass = true;
    // Không xoá `served` trước — mỗi đường dẫn tự ghi đè mốc của nó khi
    // `_cached` chạy xong (số mới nếu thành công, số cũ nếu lỗi), nên
    // không cần dọn trước. Xoá trước sẽ để lại một khoảng trống: màn nào
    // đọc syncedAt đúng lúc đang làm mới (vd Trang chủ tự vẽ lại mỗi giây)
    // sẽ thấy map rỗng hoặc chỉ mới vài đường dẫn ghi lại, hiện sai mốc
    // thay vì mốc cũ ổn định.
    try {
      await Future.wait(refreshers.map((f) => f()));
    } finally {
      bypass = false;
    }
  }

  static Future<void> init() => open();

  /// Nạp cache từ SQLite vào RAM. Màn hình đọc cache đồng bộ ngay trong
  /// build nên không chờ ổ đĩa được; SQLite là nơi lưu thật, RAM chỉ là bản
  /// sao để đọc.
  static Future<void> open() async {
    _ram.clear();
    for (final d in await Db.i.nhomDang(_nhom)) {
      _ram[d.khoa] = (jsonDecode(d.giaTri), d.luc);
    }
  }

  /// Dữ liệu đã lưu kèm lúc lưu, chưa có thì null.
  static (dynamic, DateTime)? read(String key) => _ram[key];

  static bool stale(DateTime at) => DateTime.now().difference(at) > ttl;

  /// Mốc của dữ liệu đang thật sự nằm trên màn hình, ghi lúc giao cho màn
  /// chứ không phải lúc gọi mạng. Gọi hỏng thì màn vẫn là số cũ nên mốc
  /// cũng phải đứng yên; lấy được từ cache thì mốc là lúc cache đó ghi.
  static final served = <String, DateTime>{};

  /// Cũ nhất trong đám đang hiện: nói "số trên màn mới ít nhất từ lúc này"
  /// thì không bao giờ hứa quá.
  static DateTime? get syncedAt => served.values.isEmpty
      ? null
      : served.values.reduce((a, b) => a.isBefore(b) ? a : b);

  static Future<void> write(String key, dynamic data) async {
    _ram[key] = (data, DateTime.now());
    await Db.i.ghi(_nhom, key, giaTri: jsonEncode(data));
  }

  /// Đăng xuất thì cất hết đi — ẩn chứ không xoá, đăng nhập lại ghi đè là
  /// dòng cũ sống lại.
  static Future<void> clear() async {
    served.clear();
    refreshedAt = null;
    _ram.clear();
    await Db.i.an(_nhom);
  }
}
