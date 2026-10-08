import 'dart:convert';

import 'package:dlu_tkb/clock.dart';
import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/news.dart';
import 'package:dlu_tkb/paper.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'db_tam.dart';

void main() {
  setUp(dungDbTam);

  test('unread counts IsRead == 0', () {
    expect(
      unread([
        {'IsRead': 0},
        {'IsRead': 1},
        {'IsRead': 0},
      ]),
      2,
    );
  });

  test('unread counts LMS notifications', () {
    expect(
      unread([
        (
          id: '1',
          subject: 'Mới',
          sender: 'LMS',
          date: '',
          body: '',
          unread: true,
        ),
        (
          id: '2',
          subject: 'Cũ',
          sender: 'LMS',
          date: '',
          body: '',
          unread: false,
        ),
      ]),
      1,
    );
  });

  /// Chuông với hộp thư Online rỗng; LMS chưa bật nên không gọi mạng, thông
  /// báo lấy từ SQLite.
  Future<void> dungChuong(
    WidgetTester t, {
    List<LmsEvent> suKien = const [],
    List<Map<String, dynamic>> online = const [],
  }) async {
    final now = DateTime.now();
    // Nhãn ngày của sự kiện đọc đồng hồ chung; tắt nhịp của nó cho khỏi còn
    // Timer treo lúc test xong.
    Clock.instance.set(now);
    Clock.instance.stop();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Bell(
            session: Session(
              id: '1',
              fullName: 'A',
              token: 'tk',
              expire: now.add(const Duration(hours: 1)),
            ),
            portal: Portal(
              client: MockClient(
                (_) async => http.Response.bytes(
                  utf8.encode(jsonEncode(online)),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                ),
              ),
            ),
            suKien: (_) async => suKien,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('chuông mở ra có cả sự kiện sắp đến, bấm xem thêm được', (
    t,
  ) async {
    final now = DateTime.now();
    await dungChuong(
      t,
      suKien: [
        for (var i = 1; i <= 5; i++)
          (
            name: 'Việc $i',
            course: 'CNPM',
            start: now.add(Duration(days: i)),
            keoDai: Duration.zero,
            loai: 'assign',
            url: null,
            instance: i,
            xong: false,
          ),
      ],
    );

    await t.tap(find.byType(Bell));
    await t.pumpAndSettle();
    expect(find.text('Sự kiện sắp đến'), findsOneWidget);
    expect(find.text('Việc 1'), findsOneWidget);
    expect(find.text('Việc 5'), findsNothing);

    await t.tap(find.text('Xem thêm 2 sự kiện'));
    await t.pumpAndSettle();
    expect(find.text('Việc 5'), findsOneWidget);
  });

  testWidgets('thông báo LMS đã cất trong SQLite thì mở app sau vẫn còn', (
    t,
  ) async {
    await LmsKho.luu([
      (
        id: '9',
        subject: 'Nộp bài Lab 4',
        sender: 'Giảng viên',
        date: '2026-10-02 08:00',
        body: 'Hạn nộp 23h59',
        unread: true,
      ),
    ]);
    await dungChuong(t);

    // Huy hiệu đếm đúng một tin chưa xem.
    expect(find.text('1'), findsOneWidget);
    await t.tap(find.byType(Bell));
    await t.pumpAndSettle();
    expect(find.text('Nộp bài Lab 4'), findsOneWidget);
  });

  testWidgets('thông báo LMS lên ngay, không chờ lượt gọi mạng nào', (t) async {
    await LmsKho.luu([
      (
        id: '9',
        subject: 'Nộp bài Lab 4',
        sender: 'Giảng viên',
        date: '2026-10-02 08:00',
        body: '',
        unread: true,
      ),
    ]);
    final now = DateTime.now();
    Clock.instance.set(now);
    Clock.instance.stop();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Bell(
            session: Session(
              id: '1',
              fullName: 'A',
              token: 'tk',
              expire: now.add(const Duration(hours: 1)),
            ),
            // Hộp thư Online ì ra nửa phút, y như lúc mạng trường yếu.
            portal: Portal(
              client: MockClient((_) async {
                await Future<void>.delayed(const Duration(seconds: 30));
                return http.Response.bytes(
                  utf8.encode('[]'),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }),
            ),
            suKien: (_) async => const [],
          ),
        ),
      ),
    );
    await t.pump();

    // Chữ đã nằm trong SQLite rồi thì huy hiệu phải có ngay, khỏi đợi ai.
    expect(find.text('1'), findsOneWidget);

    await t.pump(const Duration(seconds: 30));
    await t.pumpAndSettle();
  });

  testWidgets('bấm Xem là mở nội dung rồi tự đánh dấu đã xem', (t) async {
    await LmsKho.luu([
      (
        id: '9',
        subject: 'Nộp bài Lab 4',
        sender: 'Giảng viên',
        date: '2026-10-02 08:00',
        body: 'Hạn nộp 23h59',
        unread: true,
      ),
    ]);
    await dungChuong(t);
    await t.tap(find.byType(Bell));
    await t.pumpAndSettle();

    await t.tap(find.text('Xem'));
    await t.pumpAndSettle();
    // Hai chỗ: dòng rút gọn trong hộp thư và bản đầy đủ trong hộp vừa mở.
    expect(find.text('Hạn nộp 23h59'), findsNWidgets(2));
    // Hộp chi tiết mở sau nên nút Đóng của nó là cái cuối.
    await t.tap(find.text('Đóng').last);
    await t.pumpAndSettle();

    expect((await LmsKho.doc()).single.unread, isFalse);
    // Xem rồi là dòng dồn xuống mục thông báo cũ, hộp thư chỉ còn tin mới.
    expect(find.text('Nộp bài Lab 4'), findsNothing);
    await t.tap(find.text('Thông báo cũ (1)'));
    await t.pumpAndSettle();
    // Đã xem rồi thì không còn nút để đánh dấu, chỉ còn huy hiệu trạng thái —
    // nên phải tìm theo widget, tìm theo chữ là bắt luôn cả huy hiệu.
    expect(find.widgetWithText(PaperButton, 'Đã xem'), findsNothing);
    expect(find.widgetWithText(Pill, 'Đã xem'), findsOneWidget);
  });

  testWidgets('nút Đã xem đánh dấu luôn, không cần mở ra', (t) async {
    await LmsKho.luu([
      (
        id: '9',
        subject: 'Nộp bài Lab 4',
        sender: 'Giảng viên',
        date: '2026-10-02 08:00',
        body: '',
        unread: true,
      ),
    ]);
    await dungChuong(t);
    await t.tap(find.byType(Bell));
    await t.pumpAndSettle();

    await t.tap(find.widgetWithText(PaperButton, 'Đã xem'));
    await t.pumpAndSettle();
    expect((await LmsKho.doc()).single.unread, isFalse);
    await t.tap(find.text('Thông báo cũ (1)'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(PaperButton, 'Đã xem'), findsNothing);
    expect(find.widgetWithText(Pill, 'Đã xem'), findsOneWidget);

    // Đóng hộp thư là huy hiệu trên chuông cũng hết.
    await t.tap(find.text('Đóng'));
    await t.pumpAndSettle();
    expect(find.text('1'), findsNothing);
  });

  testWidgets('vuốt là xoá thông báo, nhịp LMS sau không nhận lại', (t) async {
    const tin = (
      id: '9',
      subject: 'Nộp bài Lab 4',
      sender: 'Giảng viên',
      date: '2026-10-02 08:00',
      body: '',
      unread: true,
    );
    await LmsKho.luu([tin]);
    await dungChuong(t);
    await t.tap(find.byType(Bell));
    await t.pumpAndSettle();

    await t.drag(find.text('Nộp bài Lab 4'), const Offset(500, 0));
    await t.pumpAndSettle();
    expect(find.text('Nộp bài Lab 4'), findsNothing);
    expect(find.text('Hộp thư trống.'), findsOneWidget);
    expect(await LmsKho.doc(), isEmpty);

    // Xoá không phải là mất: mở mục thông báo cũ ra là đọc lại được.
    await t.tap(find.text('Thông báo cũ (1)'));
    await t.pumpAndSettle();
    expect(find.text('Nộp bài Lab 4'), findsOneWidget);

    // Moodle vẫn trả tin đó về mỗi nhịp vì server không biết mình đã bỏ.
    await LmsKho.luu([tin]);
    expect(await LmsKho.doc(), isEmpty);
  });

  testWidgets('thư Online hiện y như thông báo LMS và đánh dấu được', (
    t,
  ) async {
    // Không có field IsRead — đúng như portal trả về — nên phải tính là chưa xem.
    await dungChuong(
      t,
      online: [
        {
          'MessageID': 7,
          'MessageSubject': 'Lịch thi học kỳ 1',
          'SenderName': 'Phòng Đào tạo',
          'CreationDate': '2026-10-01 09:00',
        },
      ],
    );
    expect(find.text('1'), findsOneWidget);

    await t.tap(find.byType(Bell));
    await t.pumpAndSettle();
    expect(find.text('Đã xem tất cả'), findsOneWidget);
    // Cùng bộ điều khiển với thông báo LMS, không còn thư chỉ đọc được.
    expect(find.widgetWithText(PaperButton, 'Xem'), findsOneWidget);
    expect(find.widgetWithText(PaperButton, 'Đã xem'), findsOneWidget);

    await t.tap(find.widgetWithText(PaperButton, 'Đã xem'));
    await t.pumpAndSettle();
    await t.tap(find.text('Thông báo cũ (1)'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(PaperButton, 'Đã xem'), findsNothing);
    expect(find.widgetWithText(Pill, 'Đã xem'), findsOneWidget);
    expect(find.text('Đã xem tất cả'), findsNothing);

    // Cờ nằm trong SQLite nên đóng hộp thư là huy hiệu cũng hết.
    await t.tap(find.text('Đóng'));
    await t.pumpAndSettle();
    expect(find.text('1'), findsNothing);
  });
}
