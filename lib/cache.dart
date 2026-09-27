import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Cache JSON của portal trong Hive: mở app là có dữ liệu ngay, hết hạn thì
/// làm mới ngầm. Box đóng (trong test) thì mọi thứ thành no-op.
class Cache {
  /// Cũ hơn ngần này thì nạp lại ngầm, còn hiển thị vẫn lấy từ cache.
  static const ttl = Duration(minutes: 30);

  static Box<String>? _box;

  /// Bật trong lúc kéo xuống làm mới: bỏ qua cache, gọi thẳng portal.
  /// ponytail: cờ toàn cục vì mỗi lần chỉ có một lượt làm mới.
  static bool bypass = false;

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
    // Vòng làm mới này giao lại số cho mọi màn đang mở; màn nào hỏng thì
    // không ghi mốc, chip lùi về mốc cũ nhất còn lại.
    served.clear();
    try {
      await Future.wait(refreshers.map((f) => f()));
    } finally {
      bypass = false;
    }
  }

  static Future<void> init() async {
    await Hive.initFlutter();
    await open();
  }

  /// Tách riêng để test mở box ở thư mục tạm.
  static Future<void> open() async =>
      _box = await Hive.openBox<String>('portal');

  /// Dữ liệu đã lưu kèm lúc lưu, chưa có thì null.
  static (dynamic, DateTime)? read(String key) {
    final raw = _box?.get(key);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return (j['data'], DateTime.parse(j['at'] as String));
  }

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
    await _box?.put(
      key,
      jsonEncode({'at': DateTime.now().toIso8601String(), 'data': data}),
    );
  }

  /// Đăng xuất thì bỏ sạch.
  static Future<void> clear() async {
    served.clear();
    refreshedAt = null;
    await _box?.clear();
  }
}
