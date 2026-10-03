import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'db.dart';
import 'luong.dart';

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

  /// Chuyển app sang sổ của một tài khoản Online. Phải nạp lại cache RAM vì
  /// nó là static: đổi tệp mà không nạp lại là màn đầu của tài khoản mới hiện
  /// số của tài khoản trước.
  static Future<void> doiSo(String? taiKhoan) async {
    served.clear();
    refreshedAt = null;
    await Db.moCho(taiKhoan);
    await open();
  }

  /// Nạp cache từ SQLite vào RAM. Màn hình đọc cache đồng bộ ngay trong
  /// build nên không chờ ổ đĩa được; SQLite là nơi lưu thật, RAM chỉ là bản
  /// sao để đọc.
  static Future<void> open() async {
    _ram.clear();
    final dong = await Db.i.nhomDang(_nhom);
    // Giải mã cả đống trong một lượt isolate: chỗ này chạy trước khung hình
    // đầu, mà cache đầy đủ là cỡ trăm KB JSON.
    final giaTri = await giaiMaNhieu([for (final d in dong) d.giaTri]);
    for (var i = 0; i < dong.length; i++) {
      _ram[dong[i].khoa] = (giaTri[i], dong[i].luc);
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
    await Db.i.ghi(_nhom, key, giaTri: await maHoa(data));
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

/// Danh sách của portal lưu theo từng mục, mỗi mục một dòng [Kho]: mục có
/// trong mẻ mới thì ghi, mục vắng mặt thì ẩn đi — không xoá dòng nào bao giờ.
///
/// Khoá dòng là chính JSON của mục, nên không cần biết endpoint nào lấy field
/// nào làm id: nội dung đổi là dòng mới (dòng cũ bị ẩn), nội dung mất khỏi mẻ
/// mới là dòng bị ẩn. Portal lỡ trả thiếu một lượt thì mục cũ chỉ ẩn, bật lại
/// được; còn ghi đè cả cục như trước là mất hẳn.
class DsKho {
  static const _nhom = 'ds';

  static String nhomCua(String path) => '$_nhom:$path';

  /// Nhập mẻ vừa lấy về và trả lại danh sách để hiển thị.
  ///
  /// Mẻ rỗng thì không ẩn gì mà trả lại nguyên những mục đang bật: portal trả
  /// rỗng hầu hết là nó lỗi, chứ không phải sinh viên hết môn — ẩn sạch theo
  /// nó là màn trống trơn vì một lượt gọi hỏng.
  static Future<List<dynamic>> nhap(String path, List<dynamic> moi) async {
    final nhom = nhomCua(path);
    final db = Db.i;
    final cu = {for (final d in await db.nhomDang(nhom)) d.khoa};
    if (moi.isEmpty) return giaiMaNhieu(cu.toList());
    final van = (await maHoaNhieu(moi)).toSet();
    // Một lượt gửi sang isolate của SQLite cho cả mẻ, chứ không mỗi mục một
    // lượt: bảng điểm hay chương trình đào tạo là vài trăm mục.
    await db.ghiAn(
      nhom,
      van.where((k) => !cu.contains(k)),
      cu.where((k) => !van.contains(k)),
    );
    return moi;
  }

  /// Mọi mục đang bật của một endpoint, không gọi mạng.
  static Future<List<dynamic>> doc(String path) async =>
      giaiMaNhieu([for (final d in await Db.i.nhomDang(nhomCua(path))) d.khoa]);
}

/// Nhịp làm mới dữ liệu portal khi app đang mở. Chỉ gọi lại những màn đang mở
/// ([Cache.refreshers]) chứ không nạp lại cả 9 endpoint: server trường yếu, mà
/// người dùng cũng chỉ nhìn một màn một lúc.
///
/// 5 phút chứ không 90 giây như [LmsNhip]: portal không đổi nhanh như hộp thư
/// Moodle, gõ cửa nó mỗi phút chỉ tốn pin hai bên.
class PortalNhip {
  @visibleForTesting
  static Duration khoang = const Duration(minutes: 5);

  static Timer? _hen;

  /// Đang chạy một lượt — lượt sau tới mà lượt này chưa về thì bỏ, đừng xếp
  /// hàng gọi portal.
  static bool _dangChay = false;

  static void chay() {
    if (_hen != null) return;
    _hen = Timer.periodic(khoang, (_) async {
      if (_dangChay || Cache.refreshers.isEmpty) return;
      _dangChay = true;
      try {
        await Cache.refreshAll();
      } catch (_) {
        // Một màn hỏng không được làm đứng nhịp.
      } finally {
        _dangChay = false;
      }
    });
  }

  /// Xuống nền thì dừng: máy khoá màn hình mà vẫn gõ cửa portal 5 phút một
  /// lượt là ăn pin không để làm gì.
  static void dung() {
    _hen?.cancel();
    _hen = null;
  }
}
