import 'dart:convert';
import 'dart:ui' show Color;

import 'package:shared_preferences/shared_preferences.dart';

/// Màu mặc định cho lịch tự đặt chưa chọn màu — hồng, khác hẳn màu vàng
/// (Paper.sun) của lịch chính quy nên không lẫn hai loại.
const customLichMauMacDinh = 0xFFFFB9CC;

/// Một mục lịch tự đặt (vd: "Lên ATC") cho ngày còn trống. [batDau] và
/// [ketThuc] là phút từ 0h; [ketThuc] không bắt buộc — có buổi chỉ biết giờ đi.
/// [mau] là ARGB người dùng chọn để phân biệt với lịch chính quy và các mục
/// tự đặt khác. [viTri] là phòng học/địa điểm, có thể để trống.
class CustomLich {
  const CustomLich({
    required this.tieuDe,
    required this.batDau,
    this.ketThuc,
    this.mau = customLichMauMacDinh,
    this.viTri,
  });
  final String tieuDe;
  final int batDau;
  final int? ketThuc;
  final int mau;
  final String? viTri;

  Color get color => Color(mau);

  /// Bản sao đã chốt giờ về là [phut] — nút "Đã xong". Chỉ giờ về đổi, màu
  /// và vị trí người dùng chọn phải còn nguyên.
  CustomLich xongLuc(int phut) => CustomLich(
    tieuDe: tieuDe,
    batDau: batDau,
    ketThuc: phut,
    mau: mau,
    viTri: viTri,
  );

  Map<String, dynamic> toJson() => {
    'tieuDe': tieuDe,
    'batDau': batDau,
    'ketThuc': ketThuc,
    'mau': mau,
    'viTri': viTri,
  };

  factory CustomLich.fromJson(Map<String, dynamic> j) => CustomLich(
    tieuDe: j['tieuDe'] as String,
    batDau: j['batDau'] as int,
    ketThuc: j['ketThuc'] as int?,
    mau: j['mau'] as int? ?? customLichMauMacDinh,
    viTri: j['viTri'] as String?,
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

  /// Toàn bộ lịch tự đặt trong một tháng, theo ngày — để tô màu lịch tháng.
  static Future<Map<int, List<CustomLich>>> forMonth(DateTime month) async {
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}-';
    final out = <int, List<CustomLich>>{};
    for (final e in (await _all()).entries) {
      if (!e.key.startsWith(prefix)) continue;
      out[int.parse(e.key.substring(prefix.length))] = e.value;
    }
    return out;
  }

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
