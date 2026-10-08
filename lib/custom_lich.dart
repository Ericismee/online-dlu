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
///
/// [lap] rỗng là mục xảy ra đúng một ngày. Có thứ trong đó ([DateTime.weekday],
/// 1 = thứ hai) thì mục lặp lại hàng tuần vào những thứ ấy, tính từ ngày đặt
/// tới [denNgay].
/// Số phút trong một ngày — giờ lịch tự đặt luôn nằm trong dải này.
const phutMotNgay = 24 * 60;

class CustomLich {
  const CustomLich({
    required this.tieuDe,
    required this.batDau,
    this.ketThuc,
    this.mau = customLichMauMacDinh,
    this.viTri,
    this.lap = const {},
    this.denNgay,
  });
  final String tieuDe;
  final int batDau;
  final int? ketThuc;
  final int mau;
  final String? viTri;
  final Set<int> lap;
  final DateTime? denNgay;

  bool get lapLai => lap.isNotEmpty;

  Color get color => Color(mau);

  CustomLich sao({
    String? tieuDe,
    int? batDau,
    int? ketThuc,
    bool xoaKetThuc = false,
    int? mau,
    String? viTri,
    Set<int>? lap,
    DateTime? denNgay,
  }) => CustomLich(
    tieuDe: tieuDe ?? this.tieuDe,
    batDau: batDau ?? this.batDau,
    ketThuc: xoaKetThuc ? null : (ketThuc ?? this.ketThuc),
    mau: mau ?? this.mau,
    viTri: viTri ?? this.viTri,
    lap: lap ?? this.lap,
    denNgay: denNgay ?? this.denNgay,
  );

  /// Bản đã chuẩn lại giờ: nằm trong một ngày, và giờ về không được trước giờ
  /// đi. Khoảng giờ lật ngược thì mục vừa thêm đã "xong" ngay, mà cảnh báo
  /// đụng giờ cũng tính sai; giờ ngoài dải 0–24h thì vào tới chỗ vẽ mới nổ
  /// (bản JSON cũ hay bản chép tay đều có thể mang số lạ). Chặn ở cửa vào
  /// SQLite thì mọi nơi gọi đều yên, khỏi phải nhớ kiểm riêng từng chỗ.
  CustomLich get chuan {
    final dau = batDau.clamp(0, phutMotNgay);
    final ve = ketThuc?.clamp(dau, phutMotNgay);
    return dau == batDau && ve == ketThuc
        ? this
        : sao(batDau: dau, ketThuc: ve, xoaKetThuc: ve == null);
  }

  /// Bản sao đã chốt giờ về là [phut] — nút "Đã xong". Chỉ giờ về đổi, màu
  /// và vị trí người dùng chọn phải còn nguyên.
  CustomLich xongLuc(int phut) => sao(ketThuc: phut);

  Map<String, dynamic> toJson() => {
    'tieuDe': tieuDe,
    'batDau': batDau,
    'ketThuc': ketThuc,
    'mau': mau,
    'viTri': viTri,
    if (lapLai) 'lap': lap.toList()..sort(),
    if (denNgay != null) 'denNgay': CustomLichStore.khoaNgay(denNgay!),
  };

  factory CustomLich.fromJson(Map<String, dynamic> j) => CustomLich(
    tieuDe: j['tieuDe'] as String,
    batDau: j['batDau'] as int,
    ketThuc: j['ketThuc'] as int?,
    mau: j['mau'] as int? ?? customLichMauMacDinh,
    viTri: j['viTri'] as String?,
    lap: _doThu(j['lap'] is List ? (j['lap'] as List).join(',') : null),
    denNgay: _doNgay(j['denNgay'] as String?),
  );
}

Set<int> _doThu(String? s) => s == null || s.isEmpty
    ? const {}
    : {
        for (final p in s.split(','))
          if (int.tryParse(p.trim()) case final n?)
            if (n >= DateTime.monday && n <= DateTime.sunday) n,
      };

DateTime? _doNgay(String? s) {
  if (s == null) return null;
  final p = s.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  return y == null || m == null || d == null ? null : DateTime(y, m, d);
}

/// Một buổi cụ thể trên lịch: [item] là nội dung, [id] là dòng gốc trong
/// SQLite, [ngay] là ngày buổi đó rơi vào. [lapLai] phân biệt buổi sinh ra từ
/// mục lặp với mục đặt riêng một ngày — xoá hai loại này khác nhau.
typedef Buoi = ({int id, DateTime ngay, CustomLich item, bool lapLai});

/// Lưu lịch tự đặt trong SQLite, mỗi mục một dòng nên xoá được từng mục —
/// mà "xoá" ở đây là tắt cờ `bat`, dòng vẫn nằm nguyên trong máy.
/// Không đụng tới lịch chính quy của portal — chỉ chen thêm vào lúc hiển thị.
class CustomLichStore {
  static String khoaNgay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static CustomLich _tu(LichRieng r) => CustomLich(
    tieuDe: r.tieuDe,
    batDau: r.batDau,
    ketThuc: r.ketThuc,
    mau: r.mau,
    viTri: r.viTri,
    lap: _doThu(r.lap),
    denNgay: _doNgay(r.denNgay),
  );

  /// Mọi dòng còn bật không phải ngoại lệ — mục một lần lẫn mục lặp.
  static Future<List<LichRieng>> _goc() {
    final db = Db.i;
    return (db.select(db.lichRiengs)
          ..where((t) => t.bat & t.goc.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();
  }

  /// Các dòng ngoại lệ (buổi đã bỏ hoặc đã sửa riêng) của mọi mục lặp.
  static Future<List<LichRieng>> _ngoaiLe() {
    final db = Db.i;
    return (db.select(db.lichRiengs)..where((t) => t.goc.isNotNull())).get();
  }

  /// Mục [r] có rơi vào ngày [d] không.
  static bool _roiVao(LichRieng r, DateTime d) {
    final key = khoaNgay(d);
    if (r.lap == null || r.lap!.isEmpty) return r.ngay == key;
    // Mục lặp chỉ chạy từ ngày đặt trở đi, và dừng ở denNgay nếu có.
    if (key.compareTo(r.ngay) < 0) return false;
    if (r.denNgay != null && key.compareTo(r.denNgay!) > 0) return false;
    return _doThu(r.lap).contains(d.weekday);
  }

  /// Các buổi của một ngày, thứ tự thêm vào. Mục lặp được trải ra thành buổi
  /// của ngày đó; buổi nào có dòng ngoại lệ thì theo dòng ngoại lệ — tắt thì
  /// biến mất, còn bật thì lấy nội dung đã sửa riêng.
  static Future<List<Buoi>> buoiTrongNgay(DateTime d) async {
    final le = _leTheoNgay(await _ngoaiLe());
    return _trai(await _goc(), le[khoaNgay(d)] ?? const {}, d);
  }

  /// Ngoại lệ gom theo ngày rồi theo mục gốc — đọc sổ một lượt là lọc được
  /// mọi ngày, khỏi quét lại cả danh sách cho từng ngày.
  static Map<String, Map<int, LichRieng>> _leTheoNgay(List<LichRieng> le) {
    final out = <String, Map<int, LichRieng>>{};
    for (final r in le) {
      (out[r.ngay] ??= {})[r.goc!] = r;
    }
    return out;
  }

  /// Trải các mục [goc] thành buổi của ngày [d], [le] là ngoại lệ của đúng
  /// ngày đó.
  static List<Buoi> _trai(
    List<LichRieng> goc,
    Map<int, LichRieng> le,
    DateTime d,
  ) {
    final out = <Buoi>[];
    for (final r in goc) {
      if (!_roiVao(r, d)) continue;
      final rieng = le[r.id];
      if (rieng != null && !rieng.bat) continue;
      out.add((
        id: r.id,
        ngay: d,
        item: _tu(rieng ?? r),
        lapLai: r.lap != null && r.lap!.isNotEmpty,
      ));
    }
    return out;
  }

  static Future<List<CustomLich>> forDay(DateTime d) async => [
    for (final b in await buoiTrongNgay(d)) b.item,
  ];

  /// Toàn bộ lịch tự đặt trong một tháng, theo ngày — để tô màu lịch tháng.
  static Future<Map<int, List<CustomLich>>> forMonth(DateTime month) async {
    final soNgay = DateTime(month.year, month.month + 1, 0).day;
    final theoNgay = await forRange(DateTime(month.year, month.month), soNgay);
    return {for (final e in theoNgay.entries) e.key.day: e.value};
  }

  /// Lịch tự đặt của [soNgay] ngày liền từ [tu], theo ngày. Đọc sổ đúng hai
  /// câu truy vấn rồi trải tại chỗ — gọi [forDay] từng ngày thì hai câu nhân
  /// lên theo số ngày mà dữ liệu đọc ra vẫn y nguyên. Ngày trống thì không
  /// có khoá.
  static Future<Map<DateTime, List<CustomLich>>> forRange(
    DateTime tu,
    int soNgay,
  ) async {
    final goc = await _goc();
    final le = _leTheoNgay(await _ngoaiLe());
    final out = <DateTime, List<CustomLich>>{};
    for (var i = 0; i < soNgay; i++) {
      final d = DateTime(tu.year, tu.month, tu.day + i);
      final ds = _trai(goc, le[khoaNgay(d)] ?? const {}, d);
      if (ds.isNotEmpty) out[d] = [for (final b in ds) b.item];
    }
    return out;
  }

  static Future<void> add(DateTime d, CustomLich moi) async {
    final item = moi.chuan;
    final db = Db.i;
    await db
        .into(db.lichRiengs)
        .insert(
          LichRiengsCompanion.insert(
            ngay: khoaNgay(d),
            tieuDe: item.tieuDe,
            batDau: item.batDau,
            ketThuc: Value(item.ketThuc),
            mau: Value(item.mau),
            viTri: Value(item.viTri),
            lap: Value(
              item.lapLai ? (item.lap.toList()..sort()).join(',') : null,
            ),
            denNgay: Value(
              item.denNgay == null ? null : khoaNgay(item.denNgay!),
            ),
            luc: DateTime.now(),
          ),
        );
  }

  /// Ẩn một buổi đi, không xoá khỏi máy. Buổi của mục lặp thì không tắt cả
  /// mục — chỉ ghi một dòng ngoại lệ tắt cho đúng ngày đó, những tuần sau
  /// vẫn còn.
  static Future<void> remove(DateTime d, int index) async {
    final ds = await buoiTrongNgay(d);
    // `indexOf` trả -1 khi mục vừa bị thẻ khác sửa mất; đừng để nó thành
    // `ds[-1]` rồi nổ giữa lúc người dùng bấm xoá.
    if (index < 0 || index >= ds.length) return;
    final b = ds[index];
    final db = Db.i;
    if (!b.lapLai) {
      await (db.update(db.lichRiengs)..where((t) => t.id.equals(b.id))).write(
        const LichRiengsCompanion(bat: Value(false)),
      );
      return;
    }
    await _ghiNgoaiLe(d, b, b.item, bat: false);
  }

  /// Tắt cả chuỗi lặp mà buổi [index] thuộc về. Dòng vẫn nằm trong máy, chỉ
  /// là `bat = false` nên không còn sinh buổi nào nữa.
  static Future<void> xoaChuoi(DateTime d, int index) async {
    final ds = await buoiTrongNgay(d);
    if (index < 0 || index >= ds.length) return;
    final db = Db.i;
    await (db.update(db.lichRiengs)..where((t) => t.id.equals(ds[index].id)))
        .write(const LichRiengsCompanion(bat: Value(false)));
  }

  /// Sửa một buổi. Buổi của mục lặp chỉ sửa riêng hôm đó; muốn đổi cả chuỗi
  /// thì xoá rồi đặt lại — người dùng ít khi đổi cả chuỗi, mà hỏi "sửa buổi
  /// này hay cả chuỗi?" thì thêm một hộp thoại nữa cho một việc hiếm.
  static Future<void> update(DateTime d, int index, CustomLich moi) async {
    final item = moi.chuan;
    final ds = await buoiTrongNgay(d);
    if (index < 0 || index >= ds.length) return;
    final b = ds[index];
    if (b.lapLai) return _ghiNgoaiLe(d, b, item, bat: true);
    final db = Db.i;
    await (db.update(
      db.lichRiengs,
    )..where((t) => t.id.equals(b.id))).write(_cot(item));
  }

  static Future<void> _ghiNgoaiLe(
    DateTime d,
    Buoi b,
    CustomLich item, {
    required bool bat,
  }) async {
    final db = Db.i;
    final cu =
        await (db.select(db.lichRiengs)
              ..where((t) => t.goc.equals(b.id) & t.ngay.equals(khoaNgay(d))))
            .getSingleOrNull();
    if (cu != null) {
      await (db.update(db.lichRiengs)..where((t) => t.id.equals(cu.id))).write(
        _cot(item).copyWith(bat: Value(bat)),
      );
      return;
    }
    await db
        .into(db.lichRiengs)
        .insert(
          LichRiengsCompanion.insert(
            ngay: khoaNgay(d),
            tieuDe: item.tieuDe,
            batDau: item.batDau,
            ketThuc: Value(item.ketThuc),
            mau: Value(item.mau),
            viTri: Value(item.viTri),
            goc: Value(b.id),
            bat: Value(bat),
            luc: DateTime.now(),
          ),
        );
  }

  static LichRiengsCompanion _cot(CustomLich item) => LichRiengsCompanion(
    tieuDe: Value(item.tieuDe),
    batDau: Value(item.batDau),
    ketThuc: Value(item.ketThuc),
    mau: Value(item.mau),
    viTri: Value(item.viTri),
    luc: Value(DateTime.now()),
  );

  /// Mục đã đặt gần đây nhất mang đúng tiêu đề này — để điền sẵn giờ, màu và
  /// vị trí cho lần sau. So tiêu đề đã chuẩn hoá nên 'lên atc' nhận ra 'Lên
  /// ATC'.
  ///
  /// Chỉ xét dòng gốc: dòng ngoại lệ là bản chụp của đúng một buổi (có khi
  /// còn là buổi đã bỏ), lấy nó làm mẫu thì chép lại cả cái sửa tạm hôm ấy.
  static Future<CustomLich?> mauGanNhat(String tieuDe) async {
    final ten = tieuDe.trim().toLowerCase();
    if (ten.isEmpty) return null;
    final db = Db.i;
    final rows =
        await (db.select(db.lichRiengs)
              ..where((t) => t.tieuDe.lower().equals(ten) & t.goc.isNull())
              ..orderBy([
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : _tu(rows.first);
  }
}
