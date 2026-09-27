import 'dart:convert';
import 'dart:io';

import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/clock.dart';
import 'package:dlu_tkb/graph.dart';
import 'package:dlu_tkb/paper.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('dlu_test_clock').path);
    await Cache.open();
  });

  tearDown(() => Cache.clear());

  test('nhịp đồng hồ canh đúng đầu phút', () {
    expect(
      Clock.nextTick(DateTime(2026, 9, 27, 23, 59, 42, 500)),
      DateTime(2026, 9, 28),
    );
    expect(
      Clock.nextTick(DateTime(2026, 9, 27, 8, 0)),
      DateTime(2026, 9, 27, 8, 1),
    );
  });

  testWidgets('0h00 sang ngày có tiết thì hiện luôn, không gọi portal', (
    t,
  ) async {
    var calls = 0;
    final portal = Portal(
      client: MockClient((req) async {
        calls++;
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
                        'CurriculumName': 'Toán',
                      },
                    ],
            }),
          ),
          200,
        );
      }),
    );

    // Nạp trước ngoài zone của test để cache Hive ghi xong hẳn.
    await t.runAsync(() => fetchMonth(portal, 't', DateTime(2026, 9)));

    // Mở app lúc 23:59 của một ngày nghỉ: chưa có gì để hiện. Tắt hẹn nhịp
    // để test tự tua giờ, và để không còn Timer treo lúc kết thúc.
    Clock.instance.set(DateTime(2026, 9, 27, 23, 59));
    Clock.instance.stop();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayLessons(
            session: Session(
              id: '1',
              fullName: 'A',
              token: 't',
              expire: DateTime(2030),
            ),
            portal: portal,
          ),
        ),
      ),
    );
    // pumpAndSettle không dùng được: đồng hồ chung luôn có Timer chờ sẵn.
    await t.pump();
    await t.pump();
    expect(find.byType(Skeleton), findsNothing, reason: 'vẫn đang tải');
    expect(find.text('Hôm nay'), findsNothing);
    final daTai = calls;
    expect(daTai, greaterThan(0));

    // Qua 0h00: lịch nguyên tháng đã nằm trong máy nên hiện ngay, không
    // thêm một lần gọi portal nào.
    Clock.instance.set(DateTime(2026, 9, 28));
    await t.pump();
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Toán'), findsWidgets);
    expect(calls, daTai);
  });
}
