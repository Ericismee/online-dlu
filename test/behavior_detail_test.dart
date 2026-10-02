import 'dart:convert';

import 'package:dlu_tkb/behavior.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(dungDbTam);

  testWidgets('phiếu rèn luyện hiện tổng điểm và điểm từng nhóm', (t) async {
    final portal = Portal(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'KetQuaDanhGia': [
                {'Scores': 89, 'BehaviorScoreRank': 'Tốt'},
              ],
              'ResultDataBangDanhGia': [
                {
                  'BehaviorGroupName': 'Ý thức học tập',
                  'MaxScoreGroup': 20,
                  'BehaviorDetailName': 'Đi học chuyên cần',
                  'MaxScore': 4,
                  'LastScore': 4,
                },
                {
                  'BehaviorGroupName': 'Ý thức học tập',
                  'MaxScoreGroup': 20,
                  'BehaviorDetailName': 'Xuất sắc',
                  'MaxScore': 10,
                  'LastScore': 0,
                },
              ],
            }),
          ),
          200,
        ),
      ),
    );
    t.view.physicalSize = const Size(1200, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: BehaviorDetailScreen(
          session: Session(
            id: '1',
            fullName: 'A',
            token: 't',
            expire: DateTime(2030),
          ),
          portal: portal,
        ),
      ),
    );
    await t.pump();
    await t.pump();

    expect(find.text('89'), findsOneWidget);
    expect(find.text('Tốt'), findsOneWidget);
    expect(find.text('4/20'), findsOneWidget);
    expect(find.text('Đi học chuyên cần'), findsOneWidget);
    // Phương án không được chọn thì không bày ra.
    expect(find.text('Xuất sắc'), findsNothing);
  });
}
