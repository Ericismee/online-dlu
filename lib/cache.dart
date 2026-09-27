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

  /// Nạp lại mọi màn đang mở, data cũ vẫn hiện cho tới khi có data mới.
  static Future<void> refreshAll() async {
    bypass = true;
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

  static DateTime? _synced;

  /// Lần cuối lấy được dữ liệu mới từ portal. Mở lại app thì dò trong box,
  /// để màn hình nói rõ đang xem số của lúc nào chứ không để người dùng đoán.
  static DateTime? get syncedAt {
    if (_synced != null) return _synced;
    for (final raw in _box?.values ?? const <String>[]) {
      final at = DateTime.tryParse(
        (jsonDecode(raw) as Map<String, dynamic>)['at'] as String? ?? '',
      );
      if (at != null && (_synced == null || at.isAfter(_synced!))) _synced = at;
    }
    return _synced;
  }

  static Future<void> write(String key, dynamic data) async {
    _synced = DateTime.now();
    await _box?.put(
      key,
      jsonEncode({'at': DateTime.now().toIso8601String(), 'data': data}),
    );
  }

  /// Đăng xuất thì bỏ sạch.
  static Future<void> clear() async {
    _synced = null;
    await _box?.clear();
  }
}
