import 'dart:ui' show Color;

import 'package:drift/drift.dart';

import 'db.dart';

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

/// Lưu lịch tự đặt trong SQLite, mỗi mục một dòng nên xoá được từng mục —
/// mà "xoá" ở đây là tắt cờ `bat`, dòng vẫn nằm nguyên trong máy.
/// Không đụng tới lịch chính quy của portal — chỉ chen thêm vào lúc hiển thị.
class CustomLichStore {
  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static CustomLich _tu(LichRieng r) => CustomLich(
    tieuDe: r.tieuDe,
    batDau: r.batDau,
    ketThuc: r.ketThuc,
    mau: r.mau,
    viTri: r.viTri,
  );

  /// Các dòng còn hiện của một ngày, thứ tự thêm vào — chỉ số trong danh
  /// sách này chính là chỉ số [remove]/[update] nhận.
  static Future<List<LichRieng>> _dong(DateTime d) {
    final db = Db.i;
    return (db.select(db.lichRiengs)
          ..where((t) => t.ngay.equals(_key(d)) & t.bat)
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();
  }

  static Future<List<CustomLich>> forDay(DateTime d) async => [
    for (final r in await _dong(d)) _tu(r),
  ];

  /// Toàn bộ lịch tự đặt trong một tháng, theo ngày — để tô màu lịch tháng.
  static Future<Map<int, List<CustomLich>>> forMonth(DateTime month) async {
    final db = Db.i;
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}-';
    final rows =
        await (db.select(db.lichRiengs)
              ..where((t) => t.ngay.like('$prefix%') & t.bat)
              ..orderBy([(t) => OrderingTerm(expression: t.id)]))
            .get();
    final out = <int, List<CustomLich>>{};
    for (final r in rows) {
      out
          .putIfAbsent(int.parse(r.ngay.substring(prefix.length)), () => [])
          .add(_tu(r));
    }
    return out;
  }

  static Future<void> add(DateTime d, CustomLich item) async {
    final db = Db.i;
    await db
        .into(db.lichRiengs)
        .insert(
          LichRiengsCompanion.insert(
            ngay: _key(d),
            tieuDe: item.tieuDe,
            batDau: item.batDau,
            ketThuc: Value(item.ketThuc),
            mau: Value(item.mau),
            viTri: Value(item.viTri),
            luc: DateTime.now(),
          ),
        );
  }

  /// Ẩn mục đi, không xoá khỏi máy.
  static Future<void> remove(DateTime d, int index) async {
    final rows = await _dong(d);
    if (index >= rows.length) return;
    final db = Db.i;
    await (db.update(db.lichRiengs)..where((t) => t.id.equals(rows[index].id)))
        .write(const LichRiengsCompanion(bat: Value(false)));
  }

  static Future<void> update(DateTime d, int index, CustomLich item) async {
    final rows = await _dong(d);
    if (index >= rows.length) return;
    final db = Db.i;
    await (db.update(
      db.lichRiengs,
    )..where((t) => t.id.equals(rows[index].id))).write(
      LichRiengsCompanion(
        tieuDe: Value(item.tieuDe),
        batDau: Value(item.batDau),
        ketThuc: Value(item.ketThuc),
        mau: Value(item.mau),
        viTri: Value(item.viTri),
        luc: Value(DateTime.now()),
      ),
    );
  }
}
