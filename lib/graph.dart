import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'cache.dart';
import 'clock.dart';
import 'custom_lich.dart';
import 'data.dart';
import 'ics.dart';
import 'lms.dart';
import 'paper.dart';
import 'portal.dart';
import 'su_kien.dart';

/// Tuần ISO của một ngày — portal đánh số tuần theo chuẩn này (21/09/2026 = 39).
int isoWeek(DateTime d) {
  final thu = d.add(Duration(days: 4 - d.weekday));
  return thu.difference(DateTime(thu.year, 1, 1)).inDays ~/ 7 + 1;
}

/// Lịch học gom theo ngày trong tháng. Key = ngày, giá trị đã sắp theo tiết.
Map<int, List<dynamic>> itemsByDay(Iterable<dynamic> items, DateTime month) {
  final out = <int, List<dynamic>>{};
  for (final i in items) {
    final p = (i['StartDate'] as String).split('/'); // dd/MM/yyyy của thứ 2
    final monday = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    final day = monday.add(Duration(days: toNum(i['DayOfWeek']).toInt() - 1));
    if (day.year != month.year || day.month != month.month) continue;
    out.putIfAbsent(day.day, () => []).add(i);
  }
  for (final l in out.values) {
    l.sort(
      (a, b) => toNum(a['PeriodID']).toInt() - toNum(b['PeriodID']).toInt(),
    );
  }
  return out;
}

/// Lịch cả tháng, gom theo ngày. Lấy nguyên tháng chứ không phải từng tuần:
/// tốn đúng mấy lần gọi mà đổi ngày, xem ngày khác đều khỏi đụng tới portal.
Future<Map<int, List<dynamic>>> fetchMonth(
  Portal portal,
  String token,
  DateTime month,
) async {
  final last = DateTime(month.year, month.month + 1, 0);
  final (year, term) = yearTermFor(month);
  final weeks = {
    for (var d = month; !d.isAfter(last); d = d.add(const Duration(days: 1)))
      isoWeek(d),
  };
  final fetched = await Future.wait(
    weeks.map(
      (w) => portal.weekSchedule(token, year: year, term: term, week: w),
    ),
  );
  return itemsByDay(fetched.expand((e) => e), month);
}

int periods(Iterable<dynamic> items) =>
    items.fold(0, (a, i) => a + toNum(i['NumberOfPeriods']).toInt());

/// (tiết đã học, tổng tiết) của tháng [thang] tính tới [now]. Buổi hôm nay chỉ
/// tính khi đã tan — đang ngồi trong lớp thì tiết đó chưa học xong.
(int, int) tietDaHoc(Map<int, List<dynamic>> thang, DateTime now) {
  var xong = 0, tong = 0;
  final phut = now.hour * 60 + now.minute;
  for (final e in thang.entries) {
    tong += periods(e.value);
    if (e.key > now.day) continue;
    if (e.key < now.day) {
      xong += periods(e.value);
      continue;
    }
    for (final i in e.value) {
      final cuoi = batDauPhut(tietNo(i['EndTime']));
      if (cuoi != null && phut >= cuoi + tietPhut) {
        xong += toNum(i['NumberOfPeriods']).toInt();
      }
    }
  }
  return (xong, tong);
}

/// Tiết 1-6 sáng, 7-10 chiều, 11-14 tối (theo bảng giờ giảng của trường).
String buoi(int periodID) =>
    periodID <= 6 ? 'Sáng' : (periodID <= 10 ? 'Chiều' : 'Tối');

/// Phút bắt đầu của từng tiết theo bảng giờ giảng của trường, mỗi tiết 50 phút.
// ponytail: trường chỉ công bố tiết 1-4, 7-14; tiết 5-6 suy ra tiếp nối tiết 4.
const _batDau = <int, int>{
  1: 7 * 60 + 30,
  2: 8 * 60 + 20,
  3: 9 * 60 + 30,
  4: 10 * 60 + 20,
  5: 11 * 60 + 10,
  6: 12 * 60,
  7: 13 * 60,
  8: 13 * 60 + 50,
  9: 14 * 60 + 50,
  10: 15 * 60 + 40,
  11: 16 * 60 + 40,
  12: 17 * 60 + 30,
  // Buổi tối cũng có giải lao 18h20 - 18h30, nên tiết 13 vào trễ 10 phút.
  13: 18 * 60 + 30,
  14: 19 * 60 + 20,
};

/// Phút bắt đầu của một tiết; tiết lạ thì null để nơi gọi khỏi bịa giờ.
int? batDauPhut(int tiet) => _batDau[tiet];

/// Mỗi tiết 50 phút.
const tietPhut = 50;

String _gio(int phut) =>
    '${phut ~/ 60}h${(phut % 60).toString().padLeft(2, '0')}';

/// Số tiết trong chuỗi portal trả về ('Tiết: 3' -> 3).
int tietNo(Object? v) =>
    int.tryParse(RegExp(r'\d+').firstMatch(clean(v))?.group(0) ?? '') ?? 0;

/// Giờ vào - giờ ra của một dải tiết. Tiết lạ thì trả null để khỏi bịa giờ.
(String, String)? khungGio(int tietDau, int tietCuoi) {
  final dau = _batDau[tietDau];
  final cuoi = _batDau[tietCuoi];
  if (dau == null || cuoi == null) return null;
  return (_gio(dau), _gio(cuoi + tietPhut));
}

/// Buổi sắp tới trong ngày: buổi đầu tiên chưa tan. Tan hết thì null.
dynamic tietKe(List<dynamic> items, DateTime now) {
  final phut = now.hour * 60 + now.minute;
  for (final i in items) {
    final cuoi = batDauPhut(tietNo(i['EndTime']));
    if (cuoi != null && phut < cuoi + tietPhut) return i;
  }
  return null;
}

/// Buổi học đang ở đoạn nào: chưa tới giờ, trong tiết, nghỉ giữa tiết, đã tan.
enum LessonPhase { chuaVao, dangHoc, raChoi, xong }

/// Đoạn hiện tại của một buổi. [tiet] là tiết đang học, hoặc tiết sắp vào khi
/// đang chờ / ra chơi; tan rồi thì null. [conPhut] là số phút còn lại của
/// chính đoạn đó — hết tiết, hết giờ ra chơi, hay tới giờ vào lớp.
typedef LessonNow = ({LessonPhase pha, int? tiet, int conPhut});

/// Buổi [item] đang tới đâu so với [now]. Tiết lạ thì null để khỏi bịa giờ.
///
/// Đi lần lượt từng tiết trong buổi nên buổi 1, 2, 3 hay 4 tiết đều đúng, và
/// khoảng trống giữa hai tiết (tiết 2 tan 9h10, tiết 3 vào 9h30) là ra chơi.
LessonNow? lessonNow(dynamic item, DateTime now) {
  final dau = tietNo(item['BeginTime']);
  final cuoi = tietNo(item['EndTime']);
  final vao = batDauPhut(dau);
  final tietCuoi = batDauPhut(cuoi);
  if (vao == null || tietCuoi == null) return null;
  final phut = now.hour * 60 + now.minute;
  if (phut < vao) {
    return (pha: LessonPhase.chuaVao, tiet: dau, conPhut: vao - phut);
  }
  for (var t = dau; t <= cuoi; t++) {
    final s = batDauPhut(t);
    if (s == null) continue;
    if (phut < s) return (pha: LessonPhase.raChoi, tiet: t, conPhut: s - phut);
    if (phut < s + tietPhut) {
      return (pha: LessonPhase.dangHoc, tiet: t, conPhut: s + tietPhut - phut);
    }
  }
  return (pha: LessonPhase.xong, tiet: null, conPhut: 0);
}

/// Nhãn và màu giấy cho đoạn hiện tại — có số tiết để biết đang ở tiết mấy.
(String, Color) phaseTag(LessonNow n) => switch (n.pha) {
  LessonPhase.chuaVao => ('Chưa vào lớp', Paper.card),
  LessonPhase.dangHoc => ('Đang học tiết ${n.tiet}', Paper.mint),
  LessonPhase.raChoi => ('Ra chơi', Paper.sun),
  LessonPhase.xong => ('Xong', Paper.paper),
};

/// Bản [phaseTag] cho lịch tự đặt — không có số tiết nên đừng nhắc "lớp"
/// hay "tiết", chỉ nói tới giờ đi/về do người dùng tự gõ.
(String, Color) phaseTagRieng(LessonNow n) => switch (n.pha) {
  LessonPhase.chuaVao => ('Chưa tới giờ', Paper.card),
  LessonPhase.dangHoc => ('Đang diễn ra', Paper.mint),
  LessonPhase.raChoi => ('Ra chơi', Paper.sun),
  LessonPhase.xong => ('Xong', Paper.paper),
};

/// Gộp lịch chính quy và lịch tự đặt của một ngày rồi sắp theo giờ vào —
/// hiển thị đúng thứ tự thời gian thay vì luôn đẩy lịch tự đặt xuống cuối.
List<Object> ganLichTrongNgay(List<dynamic> items, List<CustomLich> rieng) {
  int gioVao(Object o) => o is CustomLich
      ? o.batDau
      : (batDauPhut(tietNo((o as dynamic)['BeginTime'])) ?? 0);
  return [...items, ...rieng]..sort((a, b) => gioVao(a).compareTo(gioVao(b)));
}

/// Sắp phải đi rồi: còn 15 phút hoặc ít hơn tới giờ vào lớp.
bool sapToiGio(dynamic item, DateTime now) {
  final n = lessonNow(item, now);
  return n != null && n.pha == LessonPhase.chuaVao && n.conPhut <= 15;
}

/// '45 phút' / '2 giờ' / '1 giờ 5 phút'.
String _khoang(int phut) {
  if (phut < 60) return '$phut phút';
  final le = phut % 60;
  return '${phut ~/ 60} giờ${le == 0 ? '' : ' $le phút'}';
}

/// Còn bao lâu nữa hết đoạn đang chạy. Tan rồi hoặc tiết lạ thì null.
///
/// Đang học thì nói thẳng cái sắp tới là gì — ra chơi, tiết liền kề, hay tan —
/// chứ "còn 20 phút nữa" thì vẫn phải tự tra bảng giờ xem 20 phút nữa là được
/// nghỉ hay chỉ sang tiết tiếp.
String? demNguoc(dynamic item, DateTime now) {
  final n = lessonNow(item, now);
  return switch (n?.pha) {
    null || LessonPhase.xong => null,
    LessonPhase.chuaVao => 'Còn ${_khoang(n!.conPhut)} nữa',
    LessonPhase.dangHoc => 'Còn ${_khoang(n!.conPhut)} nữa ${_mocKe(item, n)}',
    LessonPhase.raChoi => 'Còn ${_khoang(n!.conPhut)} nữa vào tiết ${n.tiet}',
  };
}

/// Hết tiết đang học thì tới cái gì. Tiết cuối của buổi là tan; còn tiết nữa
/// thì xem bảng giờ: có khoảng trống trước tiết sau là ra chơi, không thì vào
/// thẳng tiết kế.
String _mocKe(dynamic item, LessonNow n) {
  final tiet = n.tiet!;
  if (tiet >= tietNo(item['EndTime'])) return 'tan lớp';
  final ke = batDauPhut(tiet + 1);
  if (ke == null) return 'tan lớp';
  return ke > batDauPhut(tiet)! + tietPhut ? 'ra chơi' : 'qua tiết ${tiet + 1}';
}

/// Bản [lessonNow] cho lịch tự đặt: giờ tính thẳng bằng phút, không tra bảng
/// tiết. Không có "ra chơi" vì chỉ có một khối giờ đi-về, không chia tiết.
/// Không biết giờ về thì coi như đang diễn ra cả ngày lưu nó — lưu theo
/// khoá ngày nên qua hôm sau tự không còn hiện nữa; đánh dấu xong sớm hơn
/// trong ngày thì bấm nút "Đã xong".
LessonNow? customLessonNow(CustomLich c, DateTime now) {
  final phut = now.hour * 60 + now.minute;
  if (phut < c.batDau) {
    return (pha: LessonPhase.chuaVao, tiet: null, conPhut: c.batDau - phut);
  }
  final ket = c.ketThuc;
  if (ket == null) return (pha: LessonPhase.dangHoc, tiet: null, conPhut: 0);
  if (phut < ket) {
    return (pha: LessonPhase.dangHoc, tiet: null, conPhut: ket - phut);
  }
  return (pha: LessonPhase.xong, tiet: null, conPhut: 0);
}

/// [demNguoc] cho lịch tự đặt.
String? demNguocRieng(CustomLich c, DateTime now) {
  final n = customLessonNow(c, now);
  return switch (n?.pha) {
    null || LessonPhase.xong => null,
    LessonPhase.chuaVao || LessonPhase.dangHoc =>
      c.ketThuc == null && n!.pha == LessonPhase.dangHoc
          ? null
          : 'Còn ${_khoang(n!.conPhut)} nữa',
    LessonPhase.raChoi => null,
  };
}

/// Lịch tự đặt còn hiệu lực gần nhất trong ngày (chưa "xong"), theo giờ đi.
CustomLich? ketiepRieng(List<CustomLich> rieng, DateTime now) {
  final sorted = [...rieng]..sort((a, b) => a.batDau.compareTo(b.batDau));
  for (final c in sorted) {
    if (customLessonNow(c, now)?.pha != LessonPhase.xong) return c;
  }
  return null;
}

/// Khoảng giờ (phút từ 0h) của một buổi học chính quy. Tiết lạ thì null.
(int, int)? _khoangChinhQuy(dynamic item) {
  final dau = batDauPhut(tietNo(item['BeginTime']));
  final cuoi = batDauPhut(tietNo(item['EndTime']));
  if (dau == null || cuoi == null) return null;
  return (dau, cuoi + tietPhut);
}

/// Buổi điểm danh của chính buổi học [item]: mốc điểm nằm trong khung giờ
/// buổi đó. Ghép theo giờ chứ không theo tên môn — tên trên LMS ('Mẫu Thiết
/// kế CTK47') với tên trên portal ('Mẫu thiết kế') không bao giờ khớp hẳn.
LmsEvent? diemDanhCuaBuoi(dynamic item, Iterable<LmsEvent> ds) {
  final kc = _khoangChinhQuy(item);
  if (kc == null) return null;
  for (final e in ds) {
    final phut = e.start.hour * 60 + e.start.minute;
    if (phut >= kc.$1 && phut <= kc.$2) return e;
  }
  return null;
}

/// Lịch tự đặt [c] có đụng giờ với buổi chính quy nào trong [items] của cùng
/// ngày không — không biết giờ về thì coi như chiếm hết phần ngày còn lại.
bool trungGioChinhQuy(CustomLich c, Iterable<dynamic> items) {
  final cuoiC = c.ketThuc ?? 24 * 60;
  for (final i in items) {
    final kc = _khoangChinhQuy(i);
    if (kc != null && c.batDau < kc.$2 && kc.$1 < cuoiC) return true;
  }
  return false;
}

/// Màu ô lịch theo số buổi phải lên lớp trong ngày (sáng/chiều/tối), có tính
/// luôn lịch tự đặt [rieng] của ngày đó: đụng giờ với buổi chính quy thì đè
/// màu cảnh báo; không đụng giờ thì màu theo buổi chính quy vẫn giữ nguyên
/// (quan trọng hơn); ngày trống lịch chính quy nhưng có lịch tự đặt thì tô
/// màu riêng để biết ngày đó không hẳn là nghỉ.
Color dayColor(
  Iterable<dynamic> items, [
  Iterable<CustomLich> rieng = const [],
]) {
  final buoiTrongNgay = items
      .map((i) => buoi(toNum(i['PeriodID']).toInt()))
      .toSet();
  if (rieng.any((c) => trungGioChinhQuy(c, items))) return _trungGio;
  if (buoiTrongNgay.isEmpty) return rieng.isEmpty ? _nghi : _tuDat;
  return switch (buoiTrongNgay.length) {
    1 => _motBuoi,
    2 => _haiBuoi,
    _ => _baBuoi,
  };
}

// nghỉ — không có tiết nào
Color get _nghi => Paper.nghi;
final _motBuoi = Paper.mint; // xanh lá — học 1 buổi
final _haiBuoi = Paper.sky; // xanh dương — học 2 buổi
final _baBuoi = Paper.rose; // đỏ — học cả 3 buổi
final _tuDat = Paper.peach; // cam — chỉ có lịch tự đặt, không có tiết chính quy
final _trungGio =
    Paper.accent; // đỏ cam đậm — lịch tự đặt đụng giờ tiết chính quy

/// Năm học / học kỳ của một tháng. HK01 tháng 8-1, HK02 tháng 2-6, HK03 tháng 7.
// ponytail: suy từ lịch chung của trường; nếu trường đổi mốc học kỳ thì sửa ở đây.
(String, String) yearTermFor(DateTime m) {
  final start = m.month >= 8 ? m.year : m.year - 1;
  final term = (m.month >= 8 || m.month == 1)
      ? 'HK01'
      : (m.month == 7 ? 'HK03' : 'HK02');
  return ('$start-${start + 1}', term);
}

/// Contribution graph của một tháng: mỗi ô một ngày, đậm theo số tiết.
class MonthGraph extends StatefulWidget {
  const MonthGraph({
    super.key,
    required this.session,
    required this.now,
    this.portal,
  });
  final Session session;
  final DateTime now;
  final Portal? portal;

  @override
  State<MonthGraph> createState() => _MonthGraphState();
}

class _MonthGraphState extends State<MonthGraph> with Reloadable<MonthGraph> {
  /// Nạp lại tháng đang xem, ghi đè cache trong bộ nhớ.
  @override
  Future<void> reload() async {
    final m = _month;
    try {
      final days = await _fetch(m);
      final rieng = await CustomLichStore.forMonth(m);
      if (mounted) {
        setState(() {
          _cache[_key(m)] = days;
          _riengCache[_key(m)] = rieng;
          _error = null;
        });
      }
    } on PortalError {
      // giữ nguyên lịch cũ
    }
  }

  /// Lịch đã tải, key là 'năm-tháng'. Tháng trước/sau được nạp sẵn nên bấm
  /// mũi tên là có ngay.
  final _cache = <String, Map<int, List<dynamic>>>{};
  final _riengCache = <String, Map<int, List<CustomLich>>>{};
  String? _error;
  int? _pick; // ngày đang xem, null = hôm nay
  late DateTime _month = DateTime(widget.now.year, widget.now.month);

  Map<int, List<dynamic>>? get _days => _cache[_key(_month)];
  Map<int, List<CustomLich>> get _rieng =>
      _riengCache[_key(_month)] ?? const {};
  static String _key(DateTime m) => '${m.year}-${m.month}';

  @override
  void initState() {
    super.initState();
    _show(_month);
  }

  void _goto(DateTime m) {
    setState(() {
      _month = m;
      _error = null;
      _pick = null;
    });
    _show(m);
  }

  Future<void> _show(DateTime m) async {
    if (!await _grab(m)) return;
    for (final n in [
      DateTime(m.year, m.month + 1),
      DateTime(m.year, m.month - 1),
    ]) {
      await _grab(n, quiet: true);
    }
  }

  /// Tải một tháng vào cache, trả về false khi lỗi hoặc widget đã đóng.
  Future<bool> _grab(DateTime m, {bool quiet = false}) async {
    if (_cache.containsKey(_key(m))) return true;
    try {
      final days = await _fetch(m);
      final rieng = await CustomLichStore.forMonth(m);
      if (!mounted) return false;
      setState(() {
        _cache[_key(m)] = days;
        _riengCache[_key(m)] = rieng;
        _error = null;
      });
      return true;
    } on PortalError catch (e) {
      if (mounted && !quiet) setState(() => _error = e.message);
      return false;
    }
  }

  Future<Map<int, List<dynamic>>> _fetch(DateTime month) =>
      fetchMonth(widget.portal ?? Portal(), widget.session.token, month);

  /// Chép lịch tháng sang app Lịch của máy qua file .ics.
  /// Hỏi trước vì đây là việc bước ra khỏi app.
  /// Khung để chụp đúng tấm lịch, không dính cả màn hình.

  /// Chụp tấm lịch thành ảnh rồi đưa vào bảng chia sẻ — gửi cho bạn cùng lớp
  /// nhanh hơn là tả bằng lời.
  /// Đặt lịch riêng cho ngày đang chọn. Thẻ ngày tự nạp lại nhờ
  /// [Cache.reloadAll] nên khỏi cầm tay nhau qua lại.
  Future<void> _datLichRieng(DateTime ngay) async {
    final item = await _hoiLichRieng(context);
    if (item == null) return;
    await CustomLichStore.add(ngay, item);
    Cache.reloadAll();
  }

  Future<void> _xuatLich(DateTime month) async {
    final days = _days;
    if (days == null) return;
    final n = icsCount(days);
    final ok = await confirmDialog(
      context,
      title: 'Thêm lịch tháng ${month.month}/${month.year} vào Lịch?',
      body:
          '$n buổi học sẽ được chép sang ứng dụng Lịch của máy, '
          'kèm nhắc trước giờ vào lớp 15 phút.\n\n'
          'Bấm Thêm rồi chọn Lịch trong danh sách hiện ra.',
      ok: 'Thêm',
    );
    if (!ok || !mounted) return;
    final ten = 'lich-${month.month}-${month.year}.ics';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(icsMonth(month, days)),
            mimeType: 'text/calendar',
            name: ten,
          ),
        ],
        fileNameOverrides: [ten],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final month = _month;
    final thisMonth =
        month.year == widget.now.year && month.month == widget.now.month;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = month.weekday - 1; // ô trống trước ngày 1
    final pick = _pick ?? (thisMonth ? widget.now.day : 1);
    return Column(
      children: [
        PaperBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Arrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _goto(DateTime(month.year, month.month - 1)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final m = await showDialog<DateTime>(
                            context: context,
                            builder: (_) => _MonthPicker(month: month),
                          );
                          if (m != null) _goto(m);
                        },
                        // Chữ cao ~22pt, đệm thêm cho đủ ngưỡng chạm 44pt.
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Tháng ${month.month}/${month.year}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Display',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                    color: Paper.ink,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.expand_more_rounded,
                                size: 22,
                                color: Paper.ink2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Arrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _goto(DateTime(month.year, month.month + 1)),
                  ),
                  // Số tiết nằm dưới hàng chú thích: để trên này thì hai nút
                  // mũi tên với nó chen nhau, tên tháng bị cắt mất năm.
                  if (_error != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _error!,
                        maxLines: 2,
                        style: TextStyle(color: Paper.ink2, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Nhãn thứ để ô trống trước ngày 1 nhìn ra là lịch, không phải
              // khoảng hở thừa.
              Row(
                children: [
                  for (final d in const [
                    'T2',
                    'T3',
                    'T4',
                    'T5',
                    'T6',
                    'T7',
                    'CN',
                  ])
                    Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Paper.ink2,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                // Không đặt thì GridView tự chèn padding bằng status bar,
                // thành ra hở nguyên một hàng phía trên ngày 1.
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                children: [
                  for (var i = 0; i < lead; i++) const SizedBox(),
                  if (_days == null)
                    for (var d = 1; d <= days; d++)
                      const Skeleton(height: 44, ink: true)
                  else
                    for (var d = 1; d <= days; d++)
                      _Cell(
                        day: d,
                        items: _days?[d] ?? const [],
                        rieng: _rieng[d] ?? const [],
                        today: thisMonth && d == widget.now.day,
                        picked: d == pick,
                        onTap: () => setState(() => _pick = d),
                      ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Legend(color: _motBuoi, label: '1 buổi'),
                  _Legend(color: _haiBuoi, label: '2 buổi'),
                  _Legend(color: _baBuoi, label: '3 buổi'),
                  _Legend(color: _nghi, label: 'Nghỉ'),
                  _Legend(color: _tuDat, label: 'Tự đặt'),
                  _Legend(color: _trungGio, label: 'Trùng giờ'),
                  _Legend(color: _tuDat, label: 'Có lịch tự đặt', dot: true),
                  if (_days == null)
                    const Skeleton(width: 48, height: 12)
                  else
                    Text(
                      '${periods(_days!.values.expand((e) => e))} tiết',
                      style: TextStyle(
                        color: Paper.ink2,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Mấy nút của cả tháng và của ngày đang chọn gom chung một
              // hàng ngay dưới lịch: chỗ tay đang bấm ngày, khỏi cuộn xuống.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_days != null && icsCount(_days!) > 0)
                    PaperButton(
                      label: 'Thêm vào Lịch',
                      fontSize: 13,
                      color: Paper.mint,
                      onColor: Paper.ink,
                      onPressed: () => _xuatLich(month),
                    ),
                  PaperButton(
                    label: 'Đặt lịch riêng',
                    fontSize: 13,
                    color: Paper.peach,
                    onColor: Paper.ink,
                    onPressed: () =>
                        _datLichRieng(DateTime(month.year, month.month, pick)),
                  ),
                  if (!(thisMonth && pick == widget.now.day))
                    PaperButton(
                      label: 'Xem ngày hôm nay',
                      fontSize: 13,
                      color: Paper.sky,
                      onColor: Paper.ink,
                      onPressed: () =>
                          _goto(DateTime(widget.now.year, widget.now.month)),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DayCard(
          day: DateTime(month.year, month.month, pick),
          now: thisMonth && pick == widget.now.day ? widget.now : null,
          items: _days?[pick] ?? const [],
          loading: _days == null && _error == null,
        ),
      ],
    );
  }
}

class _DayCard extends StatefulWidget {
  const _DayCard({
    required this.day,
    required this.items,
    required this.loading,
    this.now,
  });
  final DateTime day;
  final DateTime? now;
  final List<dynamic> items;
  final bool loading;

  @override
  State<_DayCard> createState() => _DayCardState();
}

/// Màn Lịch nằm trong IndexedStack nên không bị huỷ khi qua tab khác: sửa
/// lịch tự đặt ở Trang chủ (vd bấm "Đã xong") mà thẻ này không nạp lại thì
/// nó còn giữ bản cũ và vẫn báo "Đang diễn ra". Reloadable để lượt
/// `Cache.reloadAll()` sau mỗi lần sửa chạm tới nó.
class _DayCardState extends State<_DayCard> with Reloadable<_DayCard> {
  List<CustomLich>? _rieng;

  @override
  Future<void> reload() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_DayCard old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day) _load();
  }

  Future<void> _load() async {
    final d = widget.day;
    final r = await CustomLichStore.forDay(d);
    if (mounted && d == widget.day) setState(() => _rieng = r);
  }

  Future<void> _xoa(int i) async {
    await CustomLichStore.remove(widget.day, i);
    await _load();
    Cache.reloadAll();
  }

  /// Khung để chụp đúng thẻ ngày này — bấm chia sẻ là ra ảnh ngày đang xem,
  /// không phải cả tháng.
  final _anhKey = GlobalKey();

  Future<void> _chiaSeAnh() async {
    final khung = _anhKey.currentContext?.findRenderObject();
    if (khung is! RenderRepaintBoundary) return;
    // pixelRatio 3: đọc rõ trên màn retina mà file vẫn dưới 1 MB.
    final anh = await khung.toImage(pixelRatio: 3);
    final png = await anh.toByteData(format: ImageByteFormat.png);
    anh.dispose();
    if (png == null) return;
    final d = widget.day;
    final ten = 'lich-${d.day}-${d.month}-${d.year}.png';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            png.buffer.asUint8List(),
            mimeType: 'image/png',
            name: ten,
          ),
        ],
        fileNameOverrides: [ten],
        text: 'Lịch ${dayNames[d.weekday]}, ${d.day}/${d.month}/${d.year}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rieng = _rieng ?? const <CustomLich>[];
    return RepaintBoundary(
      key: _anhKey,
      child: PaperBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${dayNames[widget.day.weekday]}, ${widget.day.day}/${widget.day.month}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Display',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Paper.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.loading)
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 190, height: 16),
                  SizedBox(height: 10),
                  Skeleton(width: 240, height: 24),
                  SizedBox(height: 10),
                  Skeleton(width: 130, height: 12),
                ],
              )
            else if (widget.items.isEmpty && rieng.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Paper.sun,
                  border: Paper.border,
                  borderRadius: BorderRadius.all(Paper.radius),
                  boxShadow: Paper.shadow(3),
                ),
                child: Text(
                  'Không có tiết',
                  style: TextStyle(
                    fontFamily: 'Display',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Paper.ink,
                  ),
                ),
              )
            else ...[
              for (final (n, x) in ganLichTrongNgay(
                widget.items,
                rieng,
              ).indexed)
                if (x is CustomLich)
                  _LessonRieng(
                    x,
                    delay: Duration(milliseconds: 70 * n),
                    now: widget.now,
                    onXoa: () => _xoa(rieng.indexOf(x)),
                    trungGio: trungGioChinhQuy(x, widget.items),
                  )
                else
                  _Lesson(
                    x,
                    delay: Duration(milliseconds: 70 * n),
                    now: widget.now,
                  ),
            ],
            if (!widget.loading) ...[
              const SizedBox(height: 10),
              PaperButton(
                label: 'Chia sẻ ảnh',
                fontSize: 13,
                color: Paper.sky,
                onColor: Paper.ink,
                onPressed: _chiaSeAnh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hỏi tiêu đề, giờ đi (bắt buộc) và giờ về (tuỳ chọn) cho một mục lịch tự đặt.
Future<CustomLich?> _hoiLichRieng(BuildContext context) async {
  final ten = TextEditingController();
  final viTri = TextEditingController();
  TimeOfDay? di;
  TimeOfDay? ve;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Paper.paper,
            border: Paper.border,
            borderRadius: BorderRadius.all(Paper.radius),
            boxShadow: Paper.shadow(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đặt lịch riêng',
                style: TextStyle(
                  fontFamily: 'Display',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Paper.ink,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Paper.card,
                  border: Paper.border,
                  borderRadius: BorderRadius.all(Paper.radius),
                  boxShadow: Paper.shadow(3),
                ),
                child: TextField(
                  controller: ten,
                  autofocus: true,
                  style: TextStyle(
                    fontFamily: 'Display',
                    fontWeight: FontWeight.w700,
                    color: Paper.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'VD: Lên ATC',
                    hintStyle: TextStyle(
                      fontFamily: 'Display',
                      fontWeight: FontWeight.w700,
                      color: Paper.ink2,
                    ),
                    // 12+20+12 = 44pt, đủ ngưỡng chạm mà không phình ô.
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Paper.card,
                  border: Paper.border,
                  borderRadius: BorderRadius.all(Paper.radius),
                  boxShadow: Paper.shadow(3),
                ),
                child: TextField(
                  controller: viTri,
                  style: TextStyle(color: Paper.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Vị trí (vd: P301) — tuỳ chọn',
                    hintStyle: TextStyle(color: Paper.ink2),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Choice(
                    label: di == null
                        ? 'Giờ đi'
                        : _gio(di!.hour * 60 + di!.minute),
                    onTap: () async {
                      final t = await _chonGio(
                        ctx,
                        di ?? const TimeOfDay(hour: 7, minute: 0),
                      );
                      if (t != null) setState(() => di = t);
                    },
                  ),
                  Choice(
                    label: ve == null
                        ? 'Giờ về (tuỳ chọn)'
                        : _gio(ve!.hour * 60 + ve!.minute),
                    color: Paper.mint,
                    onTap: () async {
                      final t = await _chonGio(
                        ctx,
                        ve ?? const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (t != null) setState(() => ve = t);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PaperButton(
                    label: 'Huỷ',
                    color: Paper.card,
                    onColor: Paper.ink,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                  const SizedBox(width: 8),
                  PaperButton(
                    label: 'Thêm',
                    color: Paper.sun,
                    onColor: Paper.ink,
                    onPressed: () {
                      if (ten.text.trim().isEmpty || di == null) return;
                      Navigator.pop(ctx, true);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (ok != true || di == null) return null;
  return CustomLich(
    tieuDe: ten.text.trim(),
    batDau: di!.hour * 60 + di!.minute,
    ketThuc: ve == null ? null : ve!.hour * 60 + ve!.minute,
    viTri: viTri.text.trim().isEmpty ? null : viTri.text.trim(),
  );
}

/// Chọn giờ kiểu giấy: hai bánh xe giờ/phút thay cho đồng hồ tròn mặc định
/// của Material — cái đó không hợp phong cách viền dày, bóng cứng của app.
Future<TimeOfDay?> _chonGio(BuildContext context, TimeOfDay initial) {
  var h = initial.hour;
  var m = initial.minute ~/ 5 * 5;
  return showDialog<TimeOfDay>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Paper.paper,
          border: Paper.border,
          borderRadius: BorderRadius.all(Paper.radius),
          boxShadow: Paper.shadow(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chọn giờ',
              style: TextStyle(
                fontFamily: 'Display',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Paper.ink,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vạch giữa đánh dấu giá trị đang chọn, cùng kiểu viền
                  // ink 2px với phần còn lại của app.
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: Paper.ink, width: 2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _BanhXeSo(
                          count: 24,
                          initial: h,
                          onChanged: (v) => h = v,
                        ),
                      ),
                      Text(
                        ':',
                        style: TextStyle(
                          fontFamily: 'Display',
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: Paper.ink,
                        ),
                      ),
                      Expanded(
                        child: _BanhXeSo(
                          count: 12,
                          step: 5,
                          initial: m,
                          onChanged: (v) => m = v,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PaperButton(
                  label: 'Huỷ',
                  color: Paper.card,
                  onColor: Paper.ink,
                  onPressed: () => Navigator.pop(ctx),
                ),
                const SizedBox(width: 8),
                PaperButton(
                  label: 'Chọn',
                  color: Paper.sun,
                  onColor: Paper.ink,
                  onPressed: () =>
                      Navigator.pop(ctx, TimeOfDay(hour: h, minute: m)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Một bánh xe cuộn chọn số: chữ tiêu đề đậm, không viền mặc định
/// của Cupertino.
class _BanhXeSo extends StatelessWidget {
  const _BanhXeSo({
    required this.count,
    required this.initial,
    required this.onChanged,
    this.step = 1,
  });
  final int count;
  final int initial;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => CupertinoPicker(
    itemExtent: 36,
    scrollController: FixedExtentScrollController(initialItem: initial ~/ step),
    onSelectedItemChanged: (i) => onChanged(i * step),
    selectionOverlay: const SizedBox.shrink(),
    children: [
      for (var i = 0; i < count; i++)
        Center(
          child: Text(
            (i * step).toString().padLeft(2, '0'),
            style: TextStyle(
              fontFamily: 'Display',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Paper.ink,
            ),
          ),
        ),
    ],
  );
}

class _Lesson extends StatelessWidget {
  const _Lesson(this.i, {this.delay = Duration.zero, this.now, this.diemDanh});
  final dynamic i;
  final Duration delay;

  /// Buổi điểm danh của chính tiết này, nếu có.
  final LmsEvent? diemDanh;

  /// Chỉ ngày hôm nay mới có trạng thái; ngày khác để null.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final dau = tietNo(i['BeginTime']);
    final cuoi = tietNo(i['EndTime']);
    final gio = khungGio(dau, cuoi);
    final pha = now == null ? null : lessonNow(i, now!);
    final con = now == null ? null : demNguoc(i, now!);
    return PopIn(
      delay: delay,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cột giờ vào - giờ ra, nối bằng một vạch cho ra dáng timeline.
              if (gio != null) ...[
                SizedBox(
                  width: 46,
                  child: Column(
                    children: [
                      Text(
                        gio.$1,
                        style: TextStyle(
                          fontFamily: 'Display',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Paper.ink,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: Paper.ink3,
                          ),
                        ),
                      ),
                      Text(
                        gio.$2,
                        style: TextStyle(fontSize: 13, color: Paper.ink2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clean(i['CurriculumName']),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Paper.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (pha != null)
                          Pill(phaseTag(pha).$1, color: phaseTag(pha).$2),
                        // Đếm ngược cho từng buổi trong danh sách, không chỉ
                        // buổi nổi lên đầu: nhìn một lượt là biết tiết này còn
                        // mấy phút, ra chơi lúc nào, buổi chiều còn bao lâu.
                        if (con != null) Pill(con, color: Paper.peach),
                        // Điểm danh nằm ngay trong dòng tiết của nó: cùng một
                        // buổi học thì cùng một chỗ, khỏi thẻ riêng.
                        if (diemDanh != null && now != null)
                          ChipDiemDanh(diemDanh!, now!),
                        Pill('Tiết $dau-$cuoi', color: Paper.sun),
                        Pill(buoi(dau), color: Paper.mint),
                        Pill('Phòng ${i['RoomID']}', color: Paper.sky),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Hàng riêng chứ không nhét vào Wrap trên: tên thầy dài
                    // hơn mọi huy hiệu khác, phải có Flexible mới cắt được.
                    Row(
                      children: [
                        Flexible(
                          child: Pill(
                            'GV · ${i['FullName'] ?? '—'}',
                            color: Paper.card,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Một lịch tự đặt — cùng khung timeline và nhãn trạng thái/đếm ngược như
/// [_Lesson], không có tiết/phòng/GV. Có [onXoa] thì hiện nút xoá (thẻ ngày
/// trong Lịch), không thì thôi (danh sách hôm nay/mai ở Trang chủ).
class _LessonRieng extends StatelessWidget {
  const _LessonRieng(
    this.c, {
    this.delay = Duration.zero,
    this.now,
    this.onXoa,
    this.trungGio = false,
  });
  final CustomLich c;
  final Duration delay;
  final DateTime? now;
  final VoidCallback? onXoa;

  /// Đụng giờ với một buổi học chính quy cùng ngày.
  final bool trungGio;

  @override
  Widget build(BuildContext context) {
    final pha = now == null ? null : customLessonNow(c, now!);
    return PopIn(
      delay: delay,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 46,
                child: Column(
                  children: [
                    Text(
                      _gio(c.batDau),
                      style: TextStyle(
                        fontFamily: 'Display',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Paper.ink,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          color: Paper.ink3,
                        ),
                      ),
                    ),
                    Text(
                      c.ketThuc == null ? '—' : _gio(c.ketThuc!),
                      style: TextStyle(fontSize: 13, color: Paper.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      c.tieuDe,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Paper.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (pha != null)
                          Pill(
                            phaseTagRieng(pha).$1,
                            color: phaseTagRieng(pha).$2,
                          ),
                        Pill('Tự đặt', color: c.color),
                        if (c.viTri != null && c.viTri!.isNotEmpty)
                          Pill(c.viTri!, color: Paper.card),
                        if (trungGio) Pill('⚠ Trùng giờ', color: Paper.rose),
                      ],
                    ),
                  ],
                ),
              ),
              if (onXoa != null)
                Semantics(
                  button: true,
                  label: 'Xoá lịch riêng',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onXoa,
                    child: Padding(
                      padding: EdgeInsets.all(13),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Paper.ink3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bản [_TietKe] cho lịch tự đặt — chỉ hiện khi lịch chính quy hôm nay đã
/// tan hết, vẫn giữ đúng ưu tiên lịch chính quy phía trên.
class _TietKeRieng extends StatelessWidget {
  const _TietKeRieng({
    required this.c,
    required this.now,
    this.onXong,
    this.trungGio = false,
  });
  final CustomLich c;
  final DateTime now;

  /// Đánh dấu xong ngay — chỉ đưa vào khi mục này chưa đặt giờ về, vì có
  /// giờ về rồi thì tự "xong" đúng lúc, khỏi cần bấm.
  final VoidCallback? onXong;

  /// Đụng giờ với một buổi học chính quy — đè màu người dùng chọn bằng màu
  /// cảnh báo cho khỏi bị bỏ lỡ xung đột lịch.
  final bool trungGio;

  @override
  Widget build(BuildContext context) {
    final con = demNguocRieng(c, now);
    final pha = customLessonNow(c, now);
    final mau = pha == null ? Paper.card : phaseTagRieng(pha).$2;
    return PaperBox(
      color: trungGio ? Paper.rose : c.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(pha == null ? 'Sắp tới' : phaseTagRieng(pha).$1, color: mau),
              if (con != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    con,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Display',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Paper.ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            c.tieuDe,
            style: TextStyle(
              fontFamily: 'Display',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              height: 1.15,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                c.ketThuc == null
                    ? 'Từ ${_gio(c.batDau)}'
                    : '${_gio(c.batDau)} - ${_gio(c.ketThuc!)}',
                color: Paper.card,
              ),
              Pill('Tự đặt', color: Paper.card),
              if (c.viTri != null && c.viTri!.isNotEmpty)
                Pill(c.viTri!, color: Paper.card),
              if (trungGio) Pill('⚠ Trùng giờ chính quy', color: Paper.card),
            ],
          ),
          if (c.ketThuc == null && onXong != null) ...[
            const SizedBox(height: 10),
            PaperButton(
              label: 'Đã xong',
              fontSize: 13,
              color: Paper.mint,
              onColor: Paper.ink,
              onPressed: onXong!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Ô màu + tên buổi trong phần chú thích.
class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.dot = false});
  final Color color;
  final String label;

  /// Vẽ chấm tròn như badge thay vì ô vuông — khớp với chấm thật trên ô lịch.
  final bool dot;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: dot ? 10 : 14,
        height: dot ? 10 : 14,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Paper.ink, width: 2),
          borderRadius: dot ? null : BorderRadius.all(Paper.radius),
          shape: dot ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: Paper.ink2, fontSize: 12)),
    ],
  );
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.items,
    required this.rieng,
    required this.today,
    required this.picked,
    required this.onTap,
  });
  final int day;
  final List<dynamic> items;
  final List<CustomLich> rieng;
  final bool today, picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mau = dayColor(items, rieng);
    // Không đụng giờ thì màu ô vẫn ưu tiên buổi chính quy — chấm nhỏ góc
    // trên để biết ngày đó còn có lịch tự đặt, không thì nhìn ô dễ tưởng
    // chẳng có gì thêm ngoài giờ học.
    final coChamRieng = rieng.isNotEmpty && mau != _trungGio;
    return PopIn(
      // Lần lượt từng ngày cho ra hiệu ứng lướt qua tháng.
      delay: Duration(milliseconds: 8 * day),
      child: Pressable(
        onTap: onTap,
        builder: (down) => Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: mau,
                border: Border.all(color: Paper.ink, width: picked ? 4 : 2),
                borderRadius: BorderRadius.all(Paper.radius),
                boxShadow: picked ? Paper.shadow(down ? 0 : 2) : null,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  color: Paper.ink,
                  fontWeight: today ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            // Chấm như badge thông báo, đè ra ngoài góc ô — giống hẳn
            // chấm đỏ trên icon chuông chứ không lẫn vào số ngày.
            if (coChamRieng)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _tuDat,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Paper.paper, width: 1.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  // Nút bé tí thì khó bấm: đệm cho đủ 44pt theo chuẩn HIG.
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Paper.card,
          border: Paper.border,
          borderRadius: BorderRadius.all(Paper.radius),
          boxShadow: Paper.shadow(3),
        ),
        child: Icon(icon, size: 20, color: Paper.ink),
      ),
    ),
  );
}

/// Chọn tháng / năm: một tờ giấy với 12 ô tháng và năm đổi bằng mũi tên.
class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.month});
  final DateTime month;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.month.year;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Paper.paper,
        border: Paper.border,
        borderRadius: BorderRadius.all(Paper.radius),
        boxShadow: Paper.shadow(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Arrow(
                icon: Icons.chevron_left_rounded,
                onTap: () => setState(() => _year--),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_year',
                  style: TextStyle(
                    fontFamily: 'Display',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: Paper.ink,
                  ),
                ),
              ),
              _Arrow(
                icon: Icons.chevron_right_rounded,
                onTap: () => setState(() => _year++),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              for (var m = 1; m <= 12; m++)
                Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, DateTime(_year, m)),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            m == widget.month.month &&
                                _year == widget.month.year
                            ? Paper.sun
                            : Paper.card,
                        border: Paper.border,
                        borderRadius: BorderRadius.all(Paper.radius),
                        boxShadow: Paper.shadow(3),
                      ),
                      child: Text(
                        'Th $m',
                        style: TextStyle(
                          fontFamily: 'Display',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Paper.ink,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Tiết của hôm nay, tự ẩn nếu hôm nay nghỉ.
class TodayLessons extends StatefulWidget {
  const TodayLessons({
    super.key,
    required this.session,
    this.portal,
    this.diemDanhNguon,
  });

  /// Nguồn buổi điểm danh hôm nay; để trống là lấy thật từ LMS. Mục "Hôm nay"
  /// nắm luôn dữ liệu này vì buổi điểm danh là việc của chính tiết học — gắn
  /// vào đúng dòng tiết thì gọn hơn một thẻ riêng ở đầu trang.
  final Future<List<LmsEvent>> Function(DateTime now)? diemDanhNguon;
  final Session session;
  final Portal? portal;

  @override
  State<TodayLessons> createState() => _TodayLessonsState();
}

class _TodayLessonsState extends State<TodayLessons>
    with Reloadable<TodayLessons> {
  @override
  Future<void> reload() async {
    // Lịch tự đặt có thể vừa bị xoá/thêm ở tab khác — huỷ cache để nạp lại.
    _riengNgay = null;
    await _load(DateTime.now(), lai: true);
  }

  /// Lịch theo ngày tuyệt đối, gồm tháng này và tháng sau. Nạp sẵn cả khối
  /// nên 0h00 qua ngày mới là hiện luôn tiết hôm sau, và ngày cuối tháng
  /// vẫn xem trước được ngày mai — không phải hỏi lại portal lần nào.
  Map<DateTime, List<dynamic>>? _ngay;
  DateTime? _thang;
  bool _dangTai = false;

  /// Lịch tự đặt của đúng ngày đang hiện — nạp lại mỗi khi qua ngày mới.
  DateTime? _riengNgay;
  List<CustomLich> _riengHomNay = const [];
  List<CustomLich> _riengMai = const [];
  bool _riengDangTai = false;

  /// Buổi điểm danh hôm nay, hỏi lại theo [LmsNhip]: giáo viên hay mở buổi
  /// ngay tại lớp, chỉ lấy lúc mở app thì không bao giờ thấy.
  List<LmsEvent> _diemDanh = const [];

  @override
  void initState() {
    super.initState();
    _load(Clock.instance.value);
    LmsNhip.them(_loadDiemDanh);
    _loadDiemDanh();
  }

  @override
  void dispose() {
    LmsNhip.bo(_loadDiemDanh);
    super.dispose();
  }

  Future<void> _loadDiemDanh() async {
    var ds = _diemDanh;
    try {
      ds = await (widget.diemDanhNguon ?? diemDanhHomNay)(DateTime.now());
    } on PortalError {
      // Giữ danh sách cũ; mất mạng không có nghĩa là hết buổi điểm danh.
    }
    if (mounted) setState(() => _diemDanh = ds);
  }

  Future<void> _load(DateTime now, {bool lai = false}) async {
    final thang = DateTime(now.year, now.month);
    if (_dangTai || (!lai && _thang == thang)) return;
    _dangTai = true;
    final p = widget.portal ?? Portal();
    try {
      final ngay = await _theoNgay(p, thang);
      // Tháng sau nữa: ngày cuối tháng thì "Ngày mai" nằm bên đó. Prefetch
      // đã kéo sẵn ba tháng vào cache nên lượt này thường không đụng portal.
      try {
        ngay.addAll(await _theoNgay(p, DateTime(thang.year, thang.month + 1)));
      } on PortalError {
        // Thiếu tháng sau thì chỉ mất mục xem trước, hôm nay vẫn hiện.
      }
      if (mounted) {
        setState(() {
          _ngay = ngay;
          _thang = thang;
        });
      }
    } on PortalError {
      if (mounted) setState(() => _ngay ??= const {});
    } finally {
      _dangTai = false;
    }
  }

  /// Lịch một tháng, đổi khoá từ ngày-trong-tháng sang ngày tuyệt đối để
  /// nhiều tháng gộp chung một map mà không đụng khoá nhau.
  Future<Map<DateTime, List<dynamic>>> _theoNgay(
    Portal p,
    DateTime thang,
  ) async {
    final d = await fetchMonth(p, widget.session.token, thang);
    return {
      for (final e in d.entries)
        DateTime(thang.year, thang.month, e.key): e.value,
    };
  }

  Future<void> _loadRieng(DateTime homNay) async {
    _riengDangTai = true;
    final homNayList = await CustomLichStore.forDay(homNay);
    final maiList = await CustomLichStore.forDay(
      homNay.add(const Duration(days: 1)),
    );
    _riengDangTai = false;
    if (mounted) {
      setState(() {
        _riengNgay = homNay;
        _riengHomNay = homNayList;
        _riengMai = maiList;
      });
    }
  }

  /// Đánh dấu một mục tự đặt chưa có giờ về là xong ngay bây giờ, thay vì
  /// chờ tự "xong" lúc 0h — gán luôn giờ về là giờ hiện tại.
  Future<void> _danhDauXongRieng(DateTime homNay, int index) async {
    final list = await CustomLichStore.forDay(homNay);
    if (index >= list.length) return;
    final c = list[index];
    final gio = DateTime.now();
    await CustomLichStore.update(
      homNay,
      index,
      c.xongLuc(gio.hour * 60 + gio.minute),
    );
    await _loadRieng(homNay);
    await Cache.reloadAll();
  }

  @override
  Widget build(BuildContext context) => Ticker(
    builder: (context, now) {
      // Sang tháng mới thì mới phải gọi portal, còn sang ngày mới thì dữ
      // liệu đã nằm sẵn trong máy.
      if (_thang != null && _thang != DateTime(now.year, now.month)) {
        scheduleMicrotask(() => _load(now));
      }
      if (_ngay == null) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Skeleton(height: 120, ink: true),
        );
      }
      final homNay = DateTime(now.year, now.month, now.day);
      final items = _ngay![homNay] ?? const [];
      final ke = tietKe(items, now);
      // Hôm nay tan hết (hay hôm nay nghỉ) thì nhìn trước ngày mai luôn. Qua
      // 0h00 là homNay nhích lên, mục "Ngày mai" tự thành "Hôm nay".
      final maiItems = ke == null
          ? (_ngay![homNay.add(const Duration(days: 1))] ?? const [])
          : const [];
      if (_riengNgay != homNay && !_riengDangTai) {
        scheduleMicrotask(() => _loadRieng(homNay));
      }
      final riengHomNay = _riengNgay == homNay
          ? _riengHomNay
          : const <CustomLich>[];
      final riengMai = _riengNgay == homNay ? _riengMai : const <CustomLich>[];
      // Cả hai đều đáng nhắc: lịch chính quy hiện trước, lịch tự đặt thêm
      // bên dưới chứ không bị lịch chính quy che mất.
      final keRieng = ketiepRieng(riengHomNay, now);
      final keRiengIdx = keRieng == null ? -1 : riengHomNay.indexOf(keRieng);
      if (items.isEmpty &&
          maiItems.isEmpty &&
          riengHomNay.isEmpty &&
          riengMai.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (items.isNotEmpty || riengHomNay.isNotEmpty)
              _Ngay(
                tieuDe: 'Hôm nay',
                diemDanh: diemDanh(_diemDanh, now),
                items: items,
                rieng: riengHomNay,
                ke: ke,
                keRieng: keRieng,
                onXongRieng: keRiengIdx < 0
                    ? null
                    : () => _danhDauXongRieng(homNay, keRiengIdx),
                now: now,
              ),
            if (maiItems.isNotEmpty || riengMai.isNotEmpty) ...[
              if (items.isNotEmpty || riengHomNay.isNotEmpty)
                const SizedBox(height: 20),
              _Ngay(tieuDe: 'Ngày mai', items: maiItems, rieng: riengMai),
            ],
          ],
        ),
      );
    },
  );
}

/// Lịch tự đặt có tới trước lịch chính quy không — quyết định thẻ nào hiện
/// trước trong [_Ngay].
bool _riengTruoc(dynamic ke, CustomLich? keRieng) {
  if (keRieng == null) return false;
  if (ke == null) return true;
  return keRieng.batDau < (batDauPhut(tietNo(ke['BeginTime'])) ?? 0);
}

/// Một ngày trên Trang chủ: tiêu đề, thẻ nổi cho buổi sắp tới rồi cả danh
/// sách. Ngày mai thì [now] để null — chưa tới nên chưa có trạng thái gì.
class _Ngay extends StatelessWidget {
  const _Ngay({
    required this.tieuDe,
    required this.items,
    this.diemDanh = const [],
    this.rieng = const [],
    this.ke,
    this.keRieng,
    this.onXongRieng,
    this.now,
  });
  final String tieuDe;
  final List<LmsEvent> diemDanh;
  final List<dynamic> items;
  final List<CustomLich> rieng;
  final dynamic ke;
  final CustomLich? keRieng;
  final VoidCallback? onXongRieng;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final luc = now ?? DateTime.now();
    // Sắp tới giờ điểm — hay chẳng gắn được vào tiết nào — thì phải là thẻ
    // đầy đủ trên đầu danh sách; còn xa thì cứ nằm gọn trong dòng tiết của nó.
    final tren = [
      for (final e in diemDanh)
        if (diemDanhNoiBat(e, luc) ||
            !items.any((i) => diemDanhCuaBuoi(i, [e]) != null))
          e,
    ];
    final trongDong = [
      for (final e in diemDanh)
        if (!tren.contains(e)) e,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tieuDe,
          style: TextStyle(
            fontFamily: 'Display',
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Paper.ink,
          ),
        ),
        const SizedBox(height: 10),
        for (final e in tren) BuoiDiemDanh(e, luc),
        // Giờ nào tới trước thì thẻ đó hiện trước, không cố định lịch chính
        // quy luôn ở trên.
        if (now != null && _riengTruoc(ke, keRieng)) ...[
          _TietKeRieng(
            c: keRieng!,
            now: now!,
            onXong: onXongRieng,
            trungGio: trungGioChinhQuy(keRieng!, items),
          ),
          const SizedBox(height: 10),
        ],
        if (ke != null && now != null) ...[
          _TietKe(item: ke, now: now!),
          const SizedBox(height: 10),
        ],
        if (now != null && keRieng != null && !_riengTruoc(ke, keRieng)) ...[
          _TietKeRieng(
            c: keRieng!,
            now: now!,
            onXong: onXongRieng,
            trungGio: trungGioChinhQuy(keRieng!, items),
          ),
          const SizedBox(height: 10),
        ],
        if (items.isNotEmpty || rieng.isNotEmpty)
          PaperBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (n, x) in ganLichTrongNgay(items, rieng).indexed)
                  if (x is CustomLich)
                    _LessonRieng(
                      x,
                      delay: Duration(milliseconds: 70 * n),
                      now: now,
                      trungGio: trungGioChinhQuy(x, items),
                    )
                  else
                    _Lesson(
                      x,
                      delay: Duration(milliseconds: 70 * n),
                      now: now,
                      diemDanh: diemDanhCuaBuoi(x, trongDong),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Thẻ nổi cho buổi sắp tới: mở app ra là biết đi đâu, còn bao lâu.
class _TietKe extends StatelessWidget {
  const _TietKe({required this.item, required this.now});
  final dynamic item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final dau = tietNo(item['BeginTime']);
    final cuoi = tietNo(item['EndTime']);
    final gio = khungGio(dau, cuoi);
    final con = demNguoc(item, now);
    final pha = lessonNow(item, now);
    final gap = sapToiGio(item, now);
    // Còn 15 phút thì đổi cả thẻ sang màu cảnh báo, liếc một cái là thấy.
    final mau = gap
        ? Paper.rose
        : (pha == null ? Paper.card : phaseTag(pha).$2);
    return PaperBox(
      color: gap ? Paper.peach : Paper.sun,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Nhãn theo trạng thái thật: chưa vào lớp / đang học / ra chơi.
              Pill(
                gap
                    ? 'Sắp vào lớp'
                    : (pha == null ? 'Sắp tới' : phaseTag(pha).$1),
                color: mau,
              ),
              if (con != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    con,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Display',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Paper.ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subjectName(item['CurriculumName']),
            style: TextStyle(
              fontFamily: 'Display',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              height: 1.15,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (gio != null) Pill('${gio.$1} - ${gio.$2}', color: Paper.card),
              Pill('Phòng ${item['RoomID']}', color: Paper.card),
              Pill('Tiết $dau-$cuoi', color: Paper.card),
            ],
          ),
        ],
      ),
    );
  }
}
