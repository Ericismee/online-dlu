import 'dart:convert';

import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/clock.dart';
import 'package:dlu_tkb/custom_lich.dart';
import 'package:dlu_tkb/graph.dart';
import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:dlu_tkb/su_kien.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'db_tam.dart';

/// Buổi điểm danh thật của trường: cửa sổ 5 phút, modulename 'attendance'.
LmsEvent dd(DateTime start) => (
  name: 'Điểm danh',
  course: 'Mẫu Thiết kế CTK47',
  start: start,
  keoDai: const Duration(minutes: 5),
  loai: 'attendance',
  url: null,
  instance: 1,
  xong: false,
);

void main() {
  setUp(dungDbTam);
  tearDown(() => Cache.clear());

  /// Lịch một buổi sáng thứ 2 (28/9/2026), tiết 1-4, đúng kiểu portal trả về.
  Portal portalMotBuoi() => Portal(
    client: MockClient((req) async {
      final tuan = req.url.queryParameters['tuan'];
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'ResultDataSchedule': tuan != '40'
                ? []
                : [
                    {
                      'StartDate': '28/09/2026',
                      'DayOfWeek': 1,
                      'NumberOfPeriods': 4,
                      'PeriodID': 1,
                      'BeginTime': 'Tiết: 1',
                      'EndTime': 'Tiết: 4',
                      'CurriculumName': 'Mẫu thiết kế',
                    },
                  ],
          }),
        ),
        200,
      );
    }),
  );

  /// Mục "Hôm nay" lúc [luc] với nguồn điểm danh [nguon].
  Future<void> dungHomNay(
    WidgetTester t,
    DateTime luc,
    Future<List<LmsEvent>> Function(DateTime) nguon,
  ) async {
    final portal = portalMotBuoi();
    // Nạp trước ngoài zone của test: ghi cache SQLite thật không chạy xong
    // dưới đồng hồ giả của testWidgets.
    await t.runAsync(() async {
      for (final m in [DateTime(2026, 9), DateTime(2026, 10)]) {
        await fetchMonth(portal, 'tk', m);
      }
    });
    Clock.instance.set(luc);
    Clock.instance.stop();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TodayLessons(
              session: Session(
                id: '1',
                fullName: 'A',
                token: 'tk',
                expire: DateTime(2030),
              ),
              portal: portal,
              diemDanhNguon: nguon,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
  }

  testWidgets('thêm lịch tự đặt ở nơi khác thì mục Hôm nay hiện ngay', (
    t,
  ) async {
    await dungHomNay(t, DateTime(2026, 9, 28, 6), (_) async => const []);
    expect(find.text('Lên ATC'), findsNothing);
    // Ghi thẳng vào sổ như màn Lịch vẫn làm, không gọi `reload` hộ ai: thẻ
    // phải tự thấy, chứ không đợi kéo làm mới hay đợi lượt gọi portal.
    await t.runAsync(() async {
      await CustomLichStore.add(
        DateTime(2026, 9, 28),
        const CustomLich(tieuDe: 'Lên ATC', batDau: 13 * 60, ketThuc: 15 * 60),
      );
      // Chừa một nhịp thật cho lượt đọc sổ mà notifier vừa kích chạy xong:
      // SQLite thật không chạy dưới đồng hồ giả của testWidgets.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await t.pump();
    await t.pump();
    // Hiện cả ở dòng trong ngày và ở dòng "sắp tới" — cái nào cũng được,
    // miễn là có mà không phải bấm làm mới.
    expect(find.text('Lên ATC'), findsWidgets);
  });

  testWidgets('buổi điểm danh gắn ngay vào dòng tiết của nó', (t) async {
    final buoi = dd(DateTime(2026, 9, 28, 7, 45));
    await dungHomNay(t, DateTime(2026, 9, 28, 6), (_) async => [buoi]);

    // Một dòng duy nhất, không có thẻ riêng nào mọc thêm ở trên.
    expect(find.text('Điểm danh 7h45'), findsOneWidget);
    expect(find.byType(BuoiDiemDanh), findsNothing);
    // Và nó nằm trong chính dòng tiết "Mẫu thiết kế".
    final tiet = t.getTopLeft(find.text('Mẫu thiết kế').first).dy;
    final chip = t.getTopLeft(find.text('Điểm danh 7h45')).dy;
    expect(chip, greaterThan(tiet));
  });

  testWidgets('gần giờ điểm thì thẻ leo lên đầu, khỏi lướt qua mất', (t) async {
    final buoi = dd(DateTime(2026, 9, 28, 7, 45));
    await dungHomNay(t, DateTime(2026, 9, 28, 7, 30), (_) async => [buoi]);

    // Thẻ đầy đủ ở trên, và chỉ một chỗ nhắc điểm danh — huy hiệu trong dòng
    // tiết nhường chỗ cho nó.
    expect(find.byType(BuoiDiemDanh), findsOneWidget);
    expect(find.byType(ChipDiemDanh), findsNothing);
    expect(find.text('Mẫu Thiết kế CTK47'), findsOneWidget);
    expect(find.text('Điểm danh'), findsOneWidget);
    final the = t.getTopLeft(find.byType(BuoiDiemDanh)).dy;
    expect(t.getTopLeft(find.text('Mẫu thiết kế').first).dy, greaterThan(the));
  });

  testWidgets('tới cửa sổ điểm thì huy hiệu thành nút bấm', (t) async {
    final buoi = dd(DateTime(2026, 9, 28, 7, 45));
    await dungHomNay(t, DateTime(2026, 9, 28, 7, 46), (_) async => [buoi]);

    expect(find.text('Điểm danh ngay'), findsOneWidget);
    expect(find.text('Điểm danh 7h45'), findsNothing);
  });

  testWidgets('hết cửa sổ là huy hiệu điểm danh tự rụng', (t) async {
    final buoi = dd(DateTime(2026, 9, 28, 7, 45));
    await dungHomNay(t, DateTime(2026, 9, 28, 7, 46), (_) async => [buoi]);
    expect(find.text('Điểm danh ngay'), findsOneWidget);

    // Đồng hồ chung nhảy phút, không gọi lại mạng.
    Clock.instance.set(DateTime(2026, 9, 28, 7, 51));
    await t.pumpAndSettle();
    expect(find.textContaining('Điểm danh'), findsNothing);
  });

  testWidgets('buổi lệch hẳn khung tiết thì vẫn có thẻ riêng', (t) async {
    // 19h00: hôm nay không có tiết nào ôm được mốc này.
    final buoi = dd(DateTime(2026, 9, 28, 19));
    await dungHomNay(t, DateTime(2026, 9, 28, 6), (_) async => [buoi]);

    expect(find.byType(BuoiDiemDanh), findsOneWidget);
    expect(find.text('Mở trên LMS'), findsOneWidget);
  });

  testWidgets('buổi mở sau khi vào app vẫn bắt được, khỏi mở lại app', (
    t,
  ) async {
    // Giáo viên tạo buổi điểm danh ngay tại lớp: lượt lấy đầu chưa có gì.
    var ds = <LmsEvent>[];
    LmsNhip.khoang = () => const Duration(milliseconds: 50);
    addTearDown(() => LmsNhip.khoang = () => const Duration(seconds: 90));
    await dungHomNay(t, DateTime(2026, 9, 28, 7, 40), (_) async => ds);
    expect(find.textContaining('Điểm danh'), findsNothing);

    ds = [dd(DateTime(2026, 9, 28, 7, 45))];
    await t.pump(const Duration(milliseconds: 60));
    await t.pumpAndSettle();
    // 7h40 là đã gần giờ điểm: thẻ đầy đủ, không phải huy hiệu.
    expect(find.byType(BuoiDiemDanh), findsOneWidget);
  });
}
