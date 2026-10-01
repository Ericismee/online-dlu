import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Một mục lịch tự đặt (vd: "Lên ATC") cho ngày còn trống. [batDau] và
/// [ketThuc] là phút từ 0h; [ketThuc] không bắt buộc — có buổi chỉ biết giờ đi.
class CustomLich {
  const CustomLich({required this.tieuDe, required this.batDau, this.ketThuc});
  final String tieuDe;
  final int batDau;
  final int? ketThuc;

  Map<String, dynamic> toJson() => {
    'tieuDe': tieuDe,
    'batDau': batDau,
    'ketThuc': ketThuc,
  };

  factory CustomLich.fromJson(Map<String, dynamic> j) => CustomLich(
    tieuDe: j['tieuDe'] as String,
    batDau: j['batDau'] as int,
    ketThuc: j['ketThuc'] as int?,
  );
}

/// Lưu lịch tự đặt theo ngày trong SharedPreferences, kiểu ngày làm khoá.
/// Không đụng tới lịch chính quy của portal — chỉ chen thêm vào lúc hiển thị.
class CustomLichStore {
  static const _khoa = 'custom_lich';
  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<Map<String, List<CustomLich>>> _all() async {
    final raw = (await SharedPreferences.getInstance()).getString(_khoa);
    if (raw == null) return {};
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return j.map(
      (k, v) => MapEntry(k, [
        for (final e in v as List)
          CustomLich.fromJson(e as Map<String, dynamic>),
      ]),
    );
  }

  static Future<void> _save(Map<String, List<CustomLich>> all) async {
    final j = all.map((k, v) => MapEntry(k, [for (final c in v) c.toJson()]));
    (await SharedPreferences.getInstance()).setString(_khoa, jsonEncode(j));
  }

  static Future<List<CustomLich>> forDay(DateTime d) async =>
      (await _all())[_key(d)] ?? const [];

  static Future<void> add(DateTime d, CustomLich item) async {
    final all = await _all();
    all.putIfAbsent(_key(d), () => []).add(item);
    await _save(all);
  }

  static Future<void> remove(DateTime d, int index) async {
    final all = await _all();
    final list = all[_key(d)];
    if (list == null || index >= list.length) return;
    list.removeAt(index);
    if (list.isEmpty) all.remove(_key(d));
    await _save(all);
  }

  static Future<void> update(DateTime d, int index, CustomLich item) async {
    final all = await _all();
    final list = all[_key(d)];
    if (list == null || index >= list.length) return;
    list[index] = item;
    await _save(all);
  }
}
