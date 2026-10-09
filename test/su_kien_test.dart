import 'dart:async';

import 'package:dlu_tkb/clock.dart';
import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/paper.dart';
import 'package:dlu_tkb/su_kien.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

LmsEvent sk(
  DateTime start, {
  String name = 'Nộp bài',
  String course = 'CNPM',
  Duration keoDai = Duration.zero,
  String loai = 'assign',
}) => (
  name: name,
  course: course,
  start: start,
  keoDai: keoDai,
  loai: loai,
  url: null,
  instance: 0,
  xong: false,
);

/// Buổi điểm danh thật của trường: cửa sổ 5 phút, modulename 'attendance'.
LmsEvent dd(DateTime start, {String name = 'Điểm danh'}) => sk(
  start,
  name: name,
  course: 'DPctk47',
  keoDai: const Duration(minutes: 5),
  loai: 'attendance',
);

void main() {
  setUp(dungDbTam);

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

  test('đếm ngược làm tròn lên phút, quá giờ thì ghi theo giờ', () {
    expect(conLai(const Duration(seconds: 30)), '1 phút');
    expect(conLai(const Duration(minutes: 4, seconds: 10)), '5 phút');
    expect(conLai(const Duration(minutes: 59, seconds: 59)), '1h00');
    // Quá mốc rồi thì về 0, không hiện số âm.
    expect(conLai(const Duration(seconds: -5)), '0 phút');
    expect(conLai(const Duration(hours: 1, minutes: 20)), '1h20');
    expect(conLai(const Duration(hours: 2, minutes: 5)), '2h05');
  });

  test('quá một ngày thì đếm theo ngày cho dễ hình dung', () {
    expect(conLai(const Duration(hours: 23, minutes: 59)), '23h59');
    expect(conLai(const Duration(days: 2)), '2 ngày');
    expect(conLai(const Duration(days: 3, hours: 4)), '3 ngày 4h');
    expect(conLai(const Duration(days: 7)), '7 ngày');
  });

  test('điểm danh chỉ lấy buổi hôm nay và còn trong cửa sổ', () {
    final ds = diemDanh([
      dd(DateTime(2026, 10, 2, 7, 45)), // hôm qua
      dd(DateTime(2026, 10, 3, 7, 45)), // hôm nay nhưng đã đóng từ 7h50
      dd(DateTime(2026, 10, 3, 8, 2)), // đang mở
      dd(DateTime(2026, 10, 3, 13, 0)), // chiều nay
      dd(DateTime(2026, 10, 4, 7, 45)), // mai
    ], now);
    expect(ds.map((e) => e.start), [
      DateTime(2026, 10, 3, 8, 2),
      DateTime(2026, 10, 3, 13, 0),
    ]);
  });

  test('phút cuối của cửa sổ vẫn còn tính, qua mốc đóng là rụng', () {
    final e = dd(DateTime(2026, 10, 3, 8));
    expect(diemDanh([e], DateTime(2026, 10, 3, 8, 4, 59)), hasLength(1));
    expect(diemDanh([e], DateTime(2026, 10, 3, 8, 5)), isEmpty);
  });

  test('việc khác không phải điểm danh thì không lọt vào thẻ', () {
    expect(diemDanh([sk(DateTime(2026, 10, 3, 9))], now), isEmpty);
  });

  test('Moodle đặt tên khác modulename vẫn nhận ra theo tên', () {
    final e = sk(
      DateTime(2026, 10, 3, 9),
      name: 'Điểm danh buổi 5',
      loai: 'mod_something',
    );
    expect(diemDanh([e], now), hasLength(1));
  });

  Future<void> dung(WidgetTester t, List<LmsEvent> suKien, {int gon = 3}) {
    // Giờ cố định: lấy DateTime.now() thì chạy lúc gần nửa đêm là "hôm nay +
    // 2 giờ" nhảy sang mai, nhãn ngày lệch và test đổ oan.
    Clock.instance.set(now);
    Clock.instance.stop();
    return t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuKienNhom(suKien: suKien, gon: gon),
        ),
      ),
    );
  }

  testWidgets('gom sự kiện dưới tiêu đề từng ngày', (t) async {
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
    await dung(t, [sk(now.add(const Duration(days: 1)))], gon: 3);
    await t.pumpAndSettle();
    expect(find.textContaining('Xem thêm'), findsNothing);
  });

  Future<void> dungDemNguoc(
    WidgetTester t, {
    List<LmsEvent> kho = const [],
    Future<List<LmsEvent>> Function(DateTime)? nguon,
  }) async {
    Clock.instance.set(now);
    Clock.instance.stop();
    if (kho.isNotEmpty) await luuSuKien(kho);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SuKienCard(nguon: nguon ?? (_) async => const [])),
      ),
    );
  }

  testWidgets('thẻ đếm ngược nói việc gần nhất còn bao lâu', (t) async {
    await dungDemNguoc(
      t,
      nguon: (_) async => [
        sk(now.add(const Duration(hours: 4)), name: 'Nộp bài Lab 4'),
        sk(now.add(const Duration(days: 1)), name: 'Quiz chương 2'),
      ],
    );
    await t.pumpAndSettle();

    expect(find.text('Sắp tới'), findsOneWidget);
    expect(find.text('Nộp bài Lab 4'), findsOneWidget);
    expect(find.text('còn 4h00'), findsOneWidget);
    expect(find.text('Hôm nay · 12h00 · còn 1 việc nữa'), findsOneWidget);
  });

  testWidgets('việc còn cả tuần nữa thì chưa phải "sắp tới"', (t) async {
    await dungDemNguoc(
      t,
      nguon: (_) async => [
        sk(now.add(const Duration(days: 7)), name: 'Nộp bài Lab 4'),
      ],
    );
    await t.pumpAndSettle();
    expect(find.byType(PaperBox), findsNothing);
  });

  testWidgets('buổi điểm danh đã có thẻ riêng thì không đếm ngược lại', (
    t,
  ) async {
    await dungDemNguoc(
      t,
      nguon: (_) async => [
        dd(now.add(const Duration(hours: 1))),
        sk(now.add(const Duration(days: 2)), name: 'Nộp bài Lab 4'),
      ],
    );
    await t.pumpAndSettle();

    // Thẻ đếm ngược nhảy qua buổi điểm danh, nói việc kế tiếp — và đếm số
    // việc còn lại cũng không tính buổi đó nữa.
    expect(find.text('Điểm danh'), findsNothing);
    expect(find.text('Nộp bài Lab 4'), findsOneWidget);
    expect(find.textContaining('việc nữa'), findsNothing);
  });

  testWidgets('chỉ còn mỗi buổi điểm danh thì thẻ đếm ngược biến mất', (
    t,
  ) async {
    await dungDemNguoc(
      t,
      nguon: (_) async => [dd(now.add(const Duration(hours: 1)))],
    );
    await t.pumpAndSettle();
    expect(find.byType(PaperBox), findsNothing);
  });

  testWidgets('không còn việc nào thì thẻ không chiếm chỗ', (t) async {
    await dungDemNguoc(t);
    await t.pumpAndSettle();
    expect(find.byType(PaperBox), findsNothing);
  });

  // Đúng cái người dùng kêu: mẻ lần trước đã nằm trong máy mà vẫn phải chờ
  // trọn lượt đăng nhập LMS mới thấy.
  testWidgets('mẻ lần trước hiện ngay, không chờ lượt hỏi LMS', (t) async {
    final cham = Completer<List<LmsEvent>>();
    addTearDown(() {
      if (!cham.isCompleted) cham.complete(const []);
    });
    await dungDemNguoc(
      t,
      kho: [sk(now.add(const Duration(days: 1)), name: 'Nộp bài Lab 4')],
      nguon: (_) => cham.future,
    );
    await t.pump();

    expect(find.text('Nộp bài Lab 4'), findsOneWidget);
    expect(find.text('còn 1 ngày'), findsOneWidget);

    cham.complete(const []);
    await t.pumpAndSettle();
  });

  test('mẻ cất trong máy đọc lại đủ, mốc đã qua thì tự rụng', () async {
    await luuSuKien([
      sk(now.subtract(const Duration(days: 1)), name: 'Đã qua'),
      sk(
        now.add(const Duration(days: 2)),
        name: 'Nộp bài Lab 4',
        course: 'CNPM',
        keoDai: const Duration(minutes: 5),
      ),
    ]);
    final ds = suKienDaLuu(now);
    expect(ds.map((e) => e.name), ['Nộp bài Lab 4']);
    expect(ds.single.course, 'CNPM');
    expect(ds.single.keoDai, const Duration(minutes: 5));
  });
}
