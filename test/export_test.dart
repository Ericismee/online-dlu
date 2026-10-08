import 'dart:convert';

import 'package:dlu_tkb/graph.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(dungDbTam);

  testWidgets('xuất lịch phải hỏi trước, huỷ thì không làm gì', (t) async {
    final portal = Portal(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'ResultDataSchedule': [
                {
                  'StartDate': '31/08/2026',
                  'DayOfWeek': 2,
                  'PeriodID': 1,
                  'NumberOfPeriods': 4,
                  'BeginTime': 'Tiết: 1',
                  'EndTime': 'Tiết: 4',
                  'CurriculumName': 'Lập trình',
                  'RoomID': 'A11',
                },
              ],
            }),
          ),
          200,
        ),
      ),
    );
    // Màn test mặc định 800x600, nút xuất nằm dưới mép; kéo cao lên.
    t.view.physicalSize = const Size(1200, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              MonthGraph(
                session: Session(
                  id: '1',
                  fullName: 'A',
                  token: 't',
                  expire: DateTime(2030),
                ),
                now: DateTime(2026, 9, 1),
                portal: portal,
              ),
            ],
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();

    await t.tap(find.text('Thêm vào Lịch'));
    await t.pump();
    await t.pump();
    // Không xuất thẳng: phải có hộp hỏi với đủ hai lựa chọn.
    expect(find.textContaining('tháng 9/2026 vào Lịch?'), findsOneWidget);
    expect(
      find.textContaining('sẽ được chép sang ứng dụng Lịch'),
      findsOneWidget,
    );
    expect(find.text('Huỷ'), findsOneWidget);

    await t.tap(find.text('Huỷ'));
    await t.pump();
    await t.pump();
    expect(find.text('Huỷ'), findsNothing);
  });
}
