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
                (e.loai == 'attendance' ||
                    e.name.toLowerCase().contains('điểm danh')) &&
                DateTime(e.start.year, e.start.month, e.start.day) == homNay &&
                _dong(e).isAfter(now),
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  return out;
}

DateTime _dong(LmsEvent e) =>
    e.keoDai == Duration.zero ? e.start.add(_cuaSoToiThieu) : ketThuc(e);

/// Buổi điểm danh hôm nay, lấy từ lịch tháng này. Rỗng khi chưa bật LMS —
/// không phải lỗi, chỉ là không có gì để hiện.
Future<List<LmsEvent>> diemDanhHomNay(DateTime now, {Lms? lms}) async {
  final s = await Lms.phien(lms: lms);
  if (s == null) return const [];
  return diemDanh(await (lms ?? Lms()).calendar(s, now.year, now.month), now);
}

/// Thẻ điểm danh trên Trang chủ, đứng trên mọi thẻ khác: cả ngày chỉ có mấy
/// phút để điểm, trễ là mất buổi. Không có buổi nào hôm nay thì thẻ biến mất
/// hẳn, và cứ mỗi phút nó tự soi lại giờ nên hết cửa sổ là tự rụng.
///
/// Giáo viên hay mở buổi điểm danh ngay tại lớp, không tạo trước, nên thẻ còn
/// hỏi lại LMS theo [LmsNhip] — chỉ lấy lúc mở app thì buổi mở sau đó mình
/// không bao giờ thấy.
class DiemDanhCard extends StatefulWidget {
  const DiemDanhCard({super.key, this.nguon});

  /// Nguồn dữ liệu; để trống là lấy thật từ LMS. Chỉ test mới truyền vào.
  final Future<List<LmsEvent>> Function(DateTime now)? nguon;

  @override
  State<DiemDanhCard> createState() => _DiemDanhCardState();
}

class _DiemDanhCardState extends State<DiemDanhCard>
    with Reloadable<DiemDanhCard> {
  List<LmsEvent> _ds = const [];

  @override
  Future<void> reload() => _load();

  @override
  void initState() {
    super.initState();
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
      ds = await (widget.nguon ?? diemDanhHomNay)(DateTime.now());
    } on PortalError {
      // Giữ danh sách cũ; mất mạng không có nghĩa là hết buổi điểm danh.
    }
    if (mounted) setState(() => _ds = ds);
  }

  @override
  Widget build(BuildContext context) => Ticker(
    builder: (_, now) {
      // Lọc lại theo giờ hiện tại, không chỉ theo lúc tải: thẻ phải tự rụng
      // đúng phút cửa sổ đóng, khỏi chờ lượt làm mới sau.
      final ds = diemDanh(_ds, now);
      if (ds.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          for (final e in ds) _Buoi(e, now),
          const SizedBox(height: 20),
        ],
      );
    },
  );
}

class _Buoi extends StatelessWidget {
  const _Buoi(this.e, this.now);
  final LmsEvent e;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final mo = !e.start.isAfter(now);
    final dong = _dong(e);
    final url =
        e.url ??
        // Lịch tháng không kèm link tới buổi điểm danh, nhưng trang ngày của
        // Moodle thì mở được bằng mốc giờ, và trong đó có đường vào buổi đó.
        'https://lms.dlu.edu.vn/calendar/view.php?view=day'
            '&time=${e.start.millisecondsSinceEpoch ~/ 1000}';
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
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: Paper.shadow(3),
                  ),
                  child: const Icon(
                    Icons.how_to_reg_rounded,
                    size: 20,
                    color: Paper.ink,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    clean(e.name),
                    style: const TextStyle(
                      fontFamily: 'Baloo',
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
              const SizedBox(height: 10),
              // Tên môn là huy hiệu như mọi chỗ khác: để chữ chạy thì nó lẫn
              // vào dòng ngày giờ ngay bên dưới.
              Row(
                children: [
                  Flexible(child: Pill(clean(e.course), color: Paper.sky)),
                ],
              ),
            ],
            const SizedBox(height: 6),
            // Đủ cả ngày, khung giờ và còn bao lâu: nhìn một lần là biết có
            // phải chạy ngay hay không.
            Text(
              '${nhanNgay(DateTime(e.start.year, e.start.month, e.start.day), now)} · '
              '${gioPhut(e.start)}–${gioPhut(dong)} · '
              '${mo ? 'còn ${conLai(dong.difference(now))}' : 'mở sau ${conLai(e.start.difference(now))}'}',
              style: const TextStyle(fontSize: 13, color: Paper.ink2),
            ),
            const SizedBox(height: 14),
            PaperButton(
              label: mo ? 'Điểm danh ngay' : 'Mở trên LMS',
              color: mo ? Paper.accent : Paper.card,
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      final ds = locSuKien(_ds, now);
      if (ds.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          _DemNguoc(ds.first, now, con: ds.length - 1),
          const SizedBox(height: 20),
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
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: Paper.shadow(3),
                  ),
                  child: const Icon(
                    Icons.hourglass_bottom_rounded,
                    size: 20,
                    color: Paper.ink,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Sắp tới',
                    style: TextStyle(
                      fontFamily: 'Baloo',
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
            const SizedBox(height: 12),
            Text(
              clean(e.name),
              style: const TextStyle(
                fontFamily: 'Baloo',
                fontWeight: FontWeight.w800,
                fontSize: 17,
                height: 1.2,
                color: Paper.ink,
              ),
            ),
            if (e.course.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(child: Pill(clean(e.course), color: Paper.sky)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${nhanNgay(DateTime(e.start.year, e.start.month, e.start.day), now)}'
              ' · ${gioPhut(e.start)}'
              '${con > 0 ? ' · còn $con việc nữa' : ''}',
              style: const TextStyle(fontSize: 13, color: Paper.ink2),
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
                if (n > 0) const SizedBox(height: 14),
                Text(
                  nhanNgay(ngay, now),
                  style: const TextStyle(
                    fontFamily: 'Baloo',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Paper.ink2,
                  ),
                ),
                const SizedBox(height: 8),
                for (final e in nhom[ngay]!) SuKienHang(e),
              ],
            ],
          ),
        ),
        if (con > 0) ...[
          const SizedBox(height: 8),
          Pressable(
            onTap: () => setState(() => _het = !_het),
            builder: (_) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _het ? 'Thu gọn' : 'Xem thêm $con sự kiện',
                  style: const TextStyle(
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
                style: const TextStyle(
                  fontFamily: 'Baloo',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Paper.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clean(e.name),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Paper.ink,
                    ),
                  ),
                  if (e.course.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      clean(e.course),
                      style: const TextStyle(fontSize: 13, color: Paper.ink2),
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
