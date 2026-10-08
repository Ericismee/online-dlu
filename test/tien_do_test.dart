import 'dart:convert';

import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/clock.dart';
import 'package:dlu_tkb/main.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'db_tam.dart';

void main() {
  setUp(() async {
    await dungDbTam();
    // Đồng hồ chung chạy thật thì testWidgets báo còn timer treo.
    Clock.instance.set(DateTime(2026, 10, 5, 8));
    Clock.instance.stop();
  });
  tearDown(() => Cache.clear());

  /// Bảng điểm một kỳ: Toán 4 TC được 8.0, Lý 2 TC được 5.0 — hệ 10 là 7.00,
  /// còn hệ 4 thì portal khai thẳng 3.20.
  Portal portalDiem({bool coDiem = true}) => Portal(
    client: MockClient((req) async {
      final body = switch (req.url.path) {
        '/api/student/GetStudyProgram' => [
          {'StudyProgramID': 'CQ2021'},
        ],
        '/api/student/marks' => [
          {
            'NamHoc': '2025-2026',
            'DanhSachDiem': [
              {
                'HocKy': 'HK01',
                'DanhSachDiemHK': [
                  {
                    'CurriculumName': 'Toán',
                    'Credits': 4,
                    'DiemTK_10': coDiem ? '8.0' : null,
                    'TB_TL_TN': '3.20',
                  },
                  {
                    'CurriculumName': 'Lý',
                    'Credits': 2,
                    'DiemTK_10': coDiem ? '5.0' : null,
                  },
                ],
              },
            ],
          },
        ],
        _ => {'ResultDataSchedule': []},
      };
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    }),
  );

  Future<void> dungThe(WidgetTester t, Portal portal) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TienDoCard(
            session: Session(
              id: '1',
              fullName: 'A',
              token: 'tk',
              expire: DateTime(2030),
            ),
            portal: portal,
          ),
        ),
      ),
    );
    // Ghi cache SQLite thật không chạy xong dưới đồng hồ giả của testWidgets.
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await t.pump();
    await t.pump();
  }

  testWidgets('bấm vòng GPA là đổi qua thang 10 rồi bấm nữa là về thang 4', (
    t,
  ) async {
    await dungThe(t, portalDiem());
    expect(find.text('3.20'), findsOneWidget);
    expect(find.text('trên 4.0'), findsOneWidget);

    await t.tap(find.text('3.20'));
    await t.pumpAndSettle();
    expect(find.text('7.00'), findsOneWidget);
    expect(find.text('trên 10'), findsOneWidget);
    expect(find.text('3.20'), findsNothing);

    await t.tap(find.text('7.00'));
    await t.pumpAndSettle();
    expect(find.text('3.20'), findsOneWidget);
  });

  testWidgets('chưa môn nào có điểm hệ 10 thì bấm cũng không đổi được', (
    t,
  ) async {
    await dungThe(t, portalDiem(coDiem: false));
    expect(find.text('3.20'), findsOneWidget);
    await t.tap(find.text('3.20'));
    await t.pumpAndSettle();
    expect(find.text('3.20'), findsOneWidget);
    expect(find.text('trên 4.0'), findsOneWidget);
  });
}
