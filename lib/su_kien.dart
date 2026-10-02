import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data.dart';
import 'lms.dart';
import 'paper.dart';
import 'portal.dart';

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

/// Khối "Sự kiện sắp đến" của LMS trên Trang chủ, gom theo ngày. Chưa bật
/// LMS thì không hiện gì — không phải lỗi, chỉ là không có nguồn.
class SuKienSapToi extends StatefulWidget {
  const SuKienSapToi({super.key, this.nap});

  /// Nguồn sự kiện; để trống là lấy từ LMS thật. Chỉ test mới truyền vào.
  final Future<List<LmsEvent>> Function(DateTime now)? nap;

  @override
  State<SuKienSapToi> createState() => _SuKienSapToiState();
}

class _SuKienSapToiState extends State<SuKienSapToi>
    with Reloadable<SuKienSapToi> {
  List<LmsEvent>? _suKien;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> reload() => _load();

  Future<void> _load() async {
    try {
      final s = await (widget.nap ?? suKienSapToi)(DateTime.now());
      if (mounted) setState(() => _suKien = s);
    } on PortalError {
      // LMS hỏng thì giữ danh sách cũ, mất mạng không được xoá sạch màn hình.
      if (mounted) setState(() => _suKien ??= const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suKien = _suKien;
    // Chưa nạp xong hay không có gì: im lặng. Khối này chỉ là thêm, đừng
    // chiếm chỗ bằng ô xương cá cho người chưa bật LMS.
    if (suKien == null || suKien.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final nhom = theoNgay(suKien);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sự kiện sắp đến',
            style: TextStyle(
              fontFamily: 'Baloo',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 10),
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
                  for (final e in nhom[ngay]!) _SuKien(e),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Một sự kiện: giờ bên trái, tên với môn bên phải. Bấm là mở thẳng hoạt
/// động đó trên LMS.
class _SuKien extends StatelessWidget {
  const _SuKien(this.e);
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
