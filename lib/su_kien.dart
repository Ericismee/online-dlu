import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data.dart';
import 'lms.dart';
import 'paper.dart';

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
  Widget build(BuildContext context) {
    final con = widget.suKien.length - widget.gon;
    final hien = _het ? widget.suKien : widget.suKien.take(widget.gon).toList();
    final now = DateTime.now();
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
