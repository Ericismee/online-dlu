import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'clock.dart';
import 'data.dart';
import 'lms.dart';
import 'paper.dart';
import 'portal.dart' show PortalError;

/// Gom sự kiện theo ngày, giữ nguyên thứ tự thời gian đã sắp.
Map<DateTime, List<LmsEvent>> theoNgay(List<LmsEvent> suKien) {
  final out = <DateTime, List<LmsEvent>>{};
  for (final e in suKien) {
    final ngay = DateTime(e.start.year, e.start.month, e.start.day);
    (out[ngay] ??= []).add(e);
  }
  return out;
}

/// Nhãn ngày: gần thì gọi tên cho dễ đọc, xa thì ghi thứ với ngày.
String nhanNgay(DateTime ngay, DateTime now) {
  final cach = ngay.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (cach == 0) return 'Hôm nay';
  if (cach == 1) return 'Ngày mai';
  return '${dayNames[ngay.weekday]}, ${ngay.day}/${ngay.month}';
}

String gioPhut(DateTime t) =>
    '${t.hour}h${t.minute.toString().padLeft(2, '0')}';

/// Đếm ngược ngắn gọn, làm tròn lên phút: "4 phút", "1h20", "3 ngày 4h".
/// Quá một ngày thì đếm theo ngày: hạn nộp bài tuần sau mà ghi "168h00" thì
/// phải ngồi chia mới biết là bao lâu.
String conLai(Duration d) {
  final phut = (d.inSeconds / 60).ceil();
  if (phut < 60) return '$phut phút';
  final gio = phut ~/ 60;
  if (gio < 24) return '${gio}h${(phut % 60).toString().padLeft(2, '0')}';
  final ngay = gio ~/ 24;
  return gio % 24 == 0 ? '$ngay ngày' : '$ngay ngày ${gio % 24}h';
}

/// Buổi điểm danh Moodle không khai `timeduration` thì cho một cửa sổ chừng
/// này, không thì thẻ chẳng bao giờ kịp hiện.
/// ponytail: con số đoán, bỏ được khi nào thấy Moodle nào trả 0 thật.
const _cuaSoToiThieu = Duration(minutes: 15);

/// Buổi điểm danh của **hôm nay** và **chưa đóng cửa sổ điểm**, sắp theo giờ.
///
/// Hai điều kiện đó mới là cái quan trọng: buổi hôm qua hay buổi đã đóng thì
/// nhìn vào cũng không điểm được nữa, mà còn tưởng là mình chưa điểm. Nhận
/// dạng theo `modulename` của Moodle, tên chỉ là đường lùi cho bản Moodle nào
/// đặt khác.
List<LmsEvent> diemDanh(List<LmsEvent> suKien, DateTime now) {
  final homNay = DateTime(now.year, now.month, now.day);
  final out =
      suKien
          .where(
            (e) =>
                laDiemDanh(e) &&
                DateTime(e.start.year, e.start.month, e.start.day) == homNay &&
                _dong(e).isAfter(now),
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// Việc này có phải buổi điểm danh không. `modulename` là chuẩn, tên chỉ là
/// đường lùi cho bản Moodle nào đặt khác.
bool laDiemDanh(LmsEvent e) =>
    e.loai == 'attendance' || e.name.toLowerCase().contains('điểm danh');

DateTime _dong(LmsEvent e) =>
    e.keoDai == Duration.zero ? e.start.add(_cuaSoToiThieu) : ketThuc(e);

/// Buổi điểm danh hôm nay, lấy từ lịch tháng này. Rỗng khi chưa bật LMS —
/// không phải lỗi, chỉ là không có gì để hiện.
Future<List<LmsEvent>> diemDanhHomNay(DateTime now, {Lms? lms}) async {
  final s = await Lms.phien(lms: lms);
  if (s == null) return const [];
  return diemDanh(await (lms ?? Lms()).calendar(s, now.year, now.month), now);
}

Future<void> _moTrenLms(LmsEvent e) => launchUrl(
  Uri.parse(
    e.url ??
        'https://lms.dlu.edu.vn/calendar/view.php?view=day'
            '&time=${e.start.millisecondsSinceEpoch ~/ 1000}',
  ),
  mode: LaunchMode.externalApplication,
).then((_) {});

String _monDiemDanh(LmsEvent e) =>
    e.course.isEmpty ? clean(e.name) : clean(e.course);

Future<LmsAttendanceStatus?> _chonTrangThai(
  BuildContext context,
  LmsEvent event,
  LmsAttendanceForm form,
) => showDialog<LmsAttendanceStatus>(
  context: context,
  builder: (_) {
    LmsAttendanceStatus? selected;
    return StatefulBuilder(
      builder: (context, setState) => PaperDialog(
        title: _monDiemDanh(event),
        icon: Icons.how_to_reg_rounded,
        color: Paper.mint,
        maxWidth: 390,
        children: [
          PaperBox(
            color: Paper.sun,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, color: Paper.ink),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phiếu điểm danh đang mở',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Paper.ink,
                        ),
                      ),
                      Text(
                        '${gioPhut(event.start)}–${gioPhut(_dong(event))} · '
                        '${clean(event.name)}',
                        style: TextStyle(fontSize: 13, color: Paper.ink2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Chọn trạng thái của bạn',
            style: TextStyle(
              fontFamily: 'Display',
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Paper.ink,
            ),
          ),
          SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final status in form.statuses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        button: true,
                        selected: selected?.id == status.id,
                        label: status.label,
                        child: Pressable(
                          onTap: () => setState(() => selected = status),
                          builder: (down) {
                            final active = selected?.id == status.id;
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: active ? Paper.mint : Paper.card,
                                border: Paper.border,
                                borderRadius: BorderRadius.all(Paper.radius),
                                boxShadow: Paper.shadow(down ? 0 : 3),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    active
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: Paper.ink,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      status.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Paper.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: PaperButton(
                  label: 'Huỷ',
                  color: Paper.card,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: PaperButton(
                  label: 'Gửi điểm danh',
                  color: Paper.accent,
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(context, selected),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  },
);

/// Điểm danh ngay trong app, nhưng trạng thái vẫn do người dùng chọn và xác
/// nhận. Trước giờ mở thì giữ đường lui sang Moodle để xem thông tin buổi đó.
Future<void> moDiemDanh(BuildContext context, LmsEvent e, {Lms? lms}) async {
  if (e.start.isAfter(DateTime.now())) return _moTrenLms(e);
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Đang mở phiếu điểm danh…')),
  );
  try {
    final client = lms ?? Lms();
    final session = await Lms.phien(lms: client);
    if (session == null) throw PortalError('Bạn chưa bật tài khoản LMS');
    final form = await client.attendanceForm(session, e.instance);
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    final status = await _chonTrangThai(context, e, form);
    if (status == null || !context.mounted) return;
    await client.submitAttendance(session, form, status.id);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã gửi ${status.label} cho ${_monDiemDanh(e)} ✨'),
        ),
      );
    }
  } on PortalError catch (error) {
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(error.message),
        action: SnackBarAction(
          label: 'Mở LMS',
          onPressed: () {
            _moTrenLms(e);
          },
        ),
      ),
    );
  }
}

/// Gần giờ điểm chừng này thì thẻ điểm danh leo lên đầu mục "Hôm nay": huy
/// hiệu nằm trong dòng tiết quá nhỏ, lướt qua là không ai thấy có điểm danh.
const _noiBatTruoc = Duration(minutes: 30);

bool diemDanhNoiBat(LmsEvent e, DateTime now) =>
    e.start.difference(now) <= _noiBatTruoc;

/// Huy hiệu điểm danh gắn ngay trong dòng tiết học: chưa tới giờ thì chỉ là
/// cái nhãn, tới cửa sổ điểm là thành nút bấm được.
class ChipDiemDanh extends StatelessWidget {
  const ChipDiemDanh(this.e, this.now, {super.key});
  final LmsEvent e;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final mo = !e.start.isAfter(now);
    if (!mo) {
      return Pill('Điểm danh ${gioPhut(e.start)}', color: Paper.sun);
    }
    return PaperButton(
      label: 'Điểm danh ngay',
      fontSize: 13,
      color: Paper.accent,
      onPressed: () => moDiemDanh(context, e),
    );
  }
}

/// Thẻ đầy đủ cho một buổi điểm danh không gắn được vào tiết nào trong ngày
/// (lịch chính quy trống, hay giờ điểm lệch hẳn khỏi khung tiết).
class BuoiDiemDanh extends StatelessWidget {
  const BuoiDiemDanh(this.e, this.now, {super.key});
  final LmsEvent e;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final mo = !e.start.isAfter(now);
    final dong = _dong(e);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PaperBox(
        color: mo ? Paper.sun : Paper.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Paper.card,
                    border: Paper.border,
                    borderRadius: BorderRadius.all(Paper.radius),
                    boxShadow: Paper.shadow(3),
                  ),
                  child: Icon(
                    Icons.how_to_reg_rounded,
                    size: 20,
                    color: Paper.ink,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _monDiemDanh(e),
                    style: TextStyle(
                      fontFamily: 'Display',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Paper.ink,
                    ),
                  ),
                ),
                Pill(
                  mo ? 'Đang mở' : 'Chưa mở',
                  color: mo ? Paper.mint : Paper.card,
                ),
              ],
            ),
            if (e.course.isNotEmpty) ...[
              SizedBox(height: 5),
              Text(
                clean(e.name),
                style: TextStyle(fontSize: 13, color: Paper.ink2),
              ),
            ],
            SizedBox(height: 6),
            // Đủ cả ngày, khung giờ và còn bao lâu: nhìn một lần là biết có
            // phải chạy ngay hay không.
            Text(
              '${nhanNgay(DateTime(e.start.year, e.start.month, e.start.day), now)} · '
              '${gioPhut(e.start)}–${gioPhut(dong)} · '
              '${mo ? 'còn ${conLai(dong.difference(now))}' : 'mở sau ${conLai(e.start.difference(now))}'}',
              style: TextStyle(fontSize: 13, color: Paper.ink2),
            ),
            SizedBox(height: 14),
            PaperButton(
              label: mo ? 'Điểm danh ngay' : 'Mở trên LMS',
              color: mo ? Paper.accent : Paper.card,
              onPressed: () => moDiemDanh(context, e),
            ),
          ],
        ),
      ),
    );
  }
}

/// Xa hơn chừng này thì thôi, không làm thẻ đếm ngược nữa — nó chen lên đầu
/// Trang chủ nên phải là việc thật sự sắp phải làm.
const _sapToi = Duration(days: 2);

/// Thẻ đếm ngược trên Trang chủ: việc LMS gần nhất còn bao lâu nữa, kèm số
/// việc còn lại trong tầm nhìn. Chưa bật LMS hay không còn việc nào thì thẻ
/// biến mất hẳn.
///
/// Mẻ của lượt trước nằm trong cache nên mở app là thấy ngay; lượt hỏi LMS
/// chạy ngầm theo [LmsNhip] rồi thay số sau.
class SuKienCard extends StatefulWidget {
  const SuKienCard({super.key, this.nguon});

  /// Nguồn dữ liệu; để trống là lấy thật từ LMS. Chỉ test mới truyền vào.
  final Future<List<LmsEvent>> Function(DateTime now)? nguon;

  @override
  State<SuKienCard> createState() => _SuKienCardState();
}

class _SuKienCardState extends State<SuKienCard> with Reloadable<SuKienCard> {
  List<LmsEvent> _ds = const [];

  @override
  Future<void> reload() => _load();

  @override
  void initState() {
    super.initState();
    _ds = suKienDaLuu(Clock.instance.value);
    LmsNhip.them(_load);
    _load();
  }

  @override
  void dispose() {
    LmsNhip.bo(_load);
    super.dispose();
  }

  Future<void> _load() async {
    var ds = _ds;
    try {
      ds = await (widget.nguon ?? suKienSapToi)(DateTime.now());
    } on PortalError {
      // Giữ mẻ cũ: mất mạng không có nghĩa là hết hạn nộp bài.
    }
    if (mounted) setState(() => _ds = ds);
  }

  @override
  Widget build(BuildContext context) => Ticker(
    builder: (_, now) {
      // Lọc lại theo giờ hiện tại chứ không theo lúc tải: việc qua mốc là tự
      // rụng, khỏi chờ lượt sau.
      // Điểm danh là việc của buổi học, đã nằm trong mục "Hôm nay" cùng thẻ
      // riêng của nó — đếm ngược tới buổi điểm danh tuần sau thì chẳng để làm
      // gì. Và chỉ nhận việc đã gần: "Sắp tới" mà còn bảy ngày là không còn
      // nghĩa gì, danh sách dài hạn đã nằm trong chuông.
      final ds = [
        for (final e in locSuKien(_ds, now))
          if (!laDiemDanh(e) && e.start.difference(now) <= _sapToi) e,
      ];
      if (ds.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          _DemNguoc(ds.first, now, con: ds.length - 1),
          SizedBox(height: 20),
        ],
      );
    },
  );
}

/// Việc gần nhất: tên, môn, mốc và còn bao lâu. Bấm là mở nó trên LMS.
class _DemNguoc extends StatelessWidget {
  const _DemNguoc(this.e, this.now, {required this.con});
  final LmsEvent e;
  final DateTime now;

  /// Số việc còn lại phía sau việc này.
  final int con;

  @override
  Widget build(BuildContext context) {
    final conBaoLau = e.start.difference(now);
    // Dưới một ngày là gấp: đổi sang giấy cam cho nó đập vào mắt.
    final gap = conBaoLau < const Duration(days: 1);
    final url = e.url;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: url == null || url.isEmpty
          ? null
          : () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: PaperBox(
        color: gap ? Paper.peach : Paper.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Paper.card,
                    border: Paper.border,
                    borderRadius: BorderRadius.all(Paper.radius),
                    boxShadow: Paper.shadow(3),
                  ),
                  child: Icon(
                    Icons.hourglass_bottom_rounded,
                    size: 20,
                    color: Paper.ink,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sắp tới',
                    style: TextStyle(
                      fontFamily: 'Display',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Paper.ink,
                    ),
                  ),
                ),
                Pill(
                  'còn ${conLai(conBaoLau)}',
                  color: gap ? Paper.accent : Paper.sun,
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              clean(e.name),
              style: TextStyle(
                fontFamily: 'Display',
                fontWeight: FontWeight.w800,
                fontSize: 17,
                height: 1.2,
                color: Paper.ink,
              ),
            ),
            if (e.course.isNotEmpty) ...[
              SizedBox(height: 10),
              Row(
                children: [
                  Flexible(child: Pill(clean(e.course), color: Paper.sky)),
                ],
              ),
            ],
            SizedBox(height: 8),
            Text(
              '${nhanNgay(DateTime(e.start.year, e.start.month, e.start.day), now)}'
              ' · ${gioPhut(e.start)}'
              '${con > 0 ? ' · còn $con việc nữa' : ''}',
              style: TextStyle(fontSize: 13, color: Paper.ink2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Danh sách sự kiện gom theo ngày. Mặc định chỉ hiện [gon] mục gần nhất,
/// bấm "Xem thêm" mới trải hết — hộp thư còn phải chừa chỗ cho thông báo.
class SuKienNhom extends StatefulWidget {
  const SuKienNhom({super.key, required this.suKien, this.gon = 3});

  final List<LmsEvent> suKien;
  final int gon;

  @override
  State<SuKienNhom> createState() => _SuKienNhomState();
}

class _SuKienNhomState extends State<SuKienNhom> {
  bool _het = false;

  @override
  Widget build(BuildContext context) => Ticker(builder: _than);

  /// Nhãn ngày đọc giờ từ đồng hồ chung: app mở qua nửa đêm thì "Hôm nay"
  /// phải đổi thành "Ngày mai", chứ không giữ nhãn của lúc dựng màn.
  Widget _than(BuildContext context, DateTime now) {
    final con = widget.suKien.length - widget.gon;
    final hien = _het ? widget.suKien : widget.suKien.take(widget.gon).toList();
    final nhom = theoNgay(hien);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaperBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (n, ngay) in nhom.keys.indexed) ...[
                if (n > 0) SizedBox(height: 14),
                Text(
                  nhanNgay(ngay, now),
                  style: TextStyle(
                    fontFamily: 'Display',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Paper.ink2,
                  ),
                ),
                SizedBox(height: 8),
                for (final e in nhom[ngay]!) SuKienHang(e),
              ],
            ],
          ),
        ),
        if (con > 0) ...[
          SizedBox(height: 8),
          Pressable(
            onTap: () => setState(() => _het = !_het),
            builder: (_) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _het ? 'Thu gọn' : 'Xem thêm $con sự kiện',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Paper.ink2,
                  ),
                ),
                Icon(
                  _het
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: Paper.ink2,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Một sự kiện: giờ bên trái, tên với môn bên phải. Bấm là mở thẳng hoạt
/// động đó trên LMS.
class SuKienHang extends StatelessWidget {
  const SuKienHang(this.e, {super.key});
  final LmsEvent e;

  @override
  Widget build(BuildContext context) {
    final url = e.url;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: url == null || url.isEmpty
            ? null
            : () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 46,
              child: Text(
                gioPhut(e.start),
                style: TextStyle(
                  fontFamily: 'Display',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Paper.ink,
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clean(e.name),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Paper.ink,
                    ),
                  ),
                  if (e.course.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      clean(e.course),
                      style: TextStyle(fontSize: 13, color: Paper.ink2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
