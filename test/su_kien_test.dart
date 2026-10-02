import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/su_kien.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LmsEvent sk(
  DateTime start, {
  String name = 'Nộp bài',
  String course = 'CNPM',
}) => (name: name, course: course, start: start, url: null, instance: 0);

void main() {
  final now = DateTime(2026, 10, 3, 8);

  test('chỉ giữ sự kiện chưa tới và trong tầm nhìn trước', () {
    final loc = locSuKien([
      sk(DateTime(2026, 10, 1, 9)), // đã qua
      sk(DateTime(2026, 10, 3, 7)), // hôm nay nhưng đã qua giờ
      sk(DateTime(2026, 10, 6, 23, 59)),
      sk(DateTime(2026, 11, 20, 9)), // quá 21 ngày
    ], now);
    expect(loc.map((e) => e.start), [DateTime(2026, 10, 6, 23, 59)]);
  });

  test('sắp theo thời gian rồi cắt bớt, giữ mốc gần nhất', () {
    final loc = locSuKien(
      [
        sk(DateTime(2026, 10, 15, 7, 45)),
        sk(DateTime(2026, 10, 8, 7, 45)),
        sk(DateTime(2026, 10, 6, 23, 59)),
      ],
      now,
      toiDa: 2,
    );
    expect(loc.map((e) => e.start), [
      DateTime(2026, 10, 6, 23, 59),
      DateTime(2026, 10, 8, 7, 45),
    ]);
  });

  test('gom theo ngày, nhiều sự kiện cùng ngày về một nhóm', () {
    final nhom = theoNgay([
      sk(DateTime(2026, 10, 6, 9), name: 'Điểm danh'),
      sk(DateTime(2026, 10, 6, 23, 59), name: 'Nộp bài Lab 4'),
      sk(DateTime(2026, 10, 8, 7, 45), name: 'Điểm danh'),
    ]);
    expect(nhom.keys, [DateTime(2026, 10, 6), DateTime(2026, 10, 8)]);
    expect(nhom[DateTime(2026, 10, 6)]!.map((e) => e.name), [
      'Điểm danh',
      'Nộp bài Lab 4',
    ]);
  });

  test('nhãn ngày gần thì gọi tên, xa thì ghi thứ với ngày', () {
    expect(nhanNgay(DateTime(2026, 10, 3), now), 'Hôm nay');
    expect(nhanNgay(DateTime(2026, 10, 4), now), 'Ngày mai');
    // 8/10/2026 là thứ năm.
    expect(nhanNgay(DateTime(2026, 10, 8), now), 'Thứ 5, 8/10');
  });

  test('giờ hiển thị theo kiểu của app, phút luôn hai số', () {
    expect(gioPhut(DateTime(2026, 10, 6, 23, 59)), '23h59');
    expect(gioPhut(DateTime(2026, 10, 8, 7, 5)), '7h05');
  });

  Future<void> dung(WidgetTester t, List<LmsEvent> suKien, {int gon = 3}) =>
      t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuKienNhom(suKien: suKien, gon: gon),
          ),
        ),
      );

  testWidgets('gom sự kiện dưới tiêu đề từng ngày', (t) async {
    final now = DateTime.now();
    await dung(t, [
      sk(
        now.add(const Duration(hours: 2)),
        name: 'Nộp bài Lab 4 đến hạn',
        course: 'Phát triển ứng dụng Web nâng cao',
      ),
      sk(
        now.add(const Duration(days: 1)),
        name: 'Điểm danh',
        course: 'Mẫu Thiết kế CTK47',
      ),
    ]);
    await t.pumpAndSettle();

    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Ngày mai'), findsOneWidget);
    expect(find.text('Nộp bài Lab 4 đến hạn'), findsOneWidget);
    expect(find.text('Mẫu Thiết kế CTK47'), findsOneWidget);
  });

  testWidgets('quá tầm thì gói lại, bấm Xem thêm mới trải hết', (t) async {
    final now = DateTime.now();
    await dung(t, [
      for (var i = 1; i <= 5; i++)
        sk(now.add(Duration(days: i)), name: 'Việc $i'),
    ], gon: 2);
    await t.pumpAndSettle();

    expect(find.text('Việc 2'), findsOneWidget);
    expect(find.text('Việc 5'), findsNothing);

    await t.tap(find.text('Xem thêm 3 sự kiện'));
    await t.pumpAndSettle();
    expect(find.text('Việc 5'), findsOneWidget);

    await t.tap(find.text('Thu gọn'));
    await t.pumpAndSettle();
    expect(find.text('Việc 5'), findsNothing);
  });

  testWidgets('vừa đủ tầm thì không mọc nút Xem thêm', (t) async {
    final now = DateTime.now();
    await dung(t, [sk(now.add(const Duration(days: 1)))], gon: 3);
    await t.pumpAndSettle();
    expect(find.textContaining('Xem thêm'), findsNothing);
  });
}
