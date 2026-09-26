import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Cache JSON của portal trong Hive: mở app là có dữ liệu ngay, hết hạn thì
/// làm mới ngầm. Box đóng (trong test) thì mọi thứ thành no-op.
class Cache {
  /// Cũ hơn ngần này thì nạp lại ngầm, còn hiển thị vẫn lấy từ cache.
  static const ttl = Duration(minutes: 30);

  static Box<String>? _box;

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

  static Future<void> write(String key, dynamic data) async => _box?.put(
    key,
    jsonEncode({'at': DateTime.now().toIso8601String(), 'data': data}),
  );

  /// Kéo xuống làm mới: bỏ hết cache để màn hình nạp lại từ portal.
  static Future<void> clear() async => _box?.clear();
}
