import 'dart:convert';

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
        (subject: 'Mới', sender: 'LMS', date: '', body: '', unread: true),
        (subject: 'Cũ', sender: 'LMS', date: '', body: '', unread: false),
      ]),
      1,
    );
  });

  testWidgets('chuông mở ra có cả sự kiện sắp đến, bấm xem thêm được', (
    t,
  ) async {
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
            suKien: (now) async => [
              for (var i = 1; i <= 5; i++)
                (
                  name: 'Việc $i',
                  course: 'CNPM',
                  start: now.add(Duration(days: i)),
                  url: null,
                  instance: i,
                ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.byType(Bell));
    await t.pumpAndSettle();
    expect(find.text('Sự kiện sắp đến'), findsOneWidget);
    expect(find.text('Việc 1'), findsOneWidget);
    expect(find.text('Việc 5'), findsNothing);

    await t.tap(find.text('Xem thêm 2 sự kiện'));
    await t.pumpAndSettle();
    expect(find.text('Việc 5'), findsOneWidget);
  });
}
