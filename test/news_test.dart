import 'dart:convert';

import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/news.dart';
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
  }) async {
    final now = DateTime.now();
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
                  utf8.encode(jsonEncode([])),
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
    // Đã xem rồi thì không còn gì để đánh dấu.
    expect(find.text('Đã xem'), findsNothing);
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

    await t.tap(find.text('Đã xem'));
    await t.pumpAndSettle();
    expect((await LmsKho.doc()).single.unread, isFalse);
    expect(find.text('Đã xem'), findsNothing);

    // Đóng hộp thư là huy hiệu trên chuông cũng hết.
    await t.tap(find.text('Đóng'));
    await t.pumpAndSettle();
    expect(find.text('1'), findsNothing);
  });
}
