import 'dart:convert';

import 'package:dlu_tkb/info.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'db_tam.dart';

void main() {
  for (final width in [280.0, 360.0]) {
    testWidgets('hồ sơ gọn và không tràn ở ${width.toInt()}dp', (tester) async {
      tester.view.physicalSize = Size(width * 3, 2100);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await dungDbTam();
      final portal = Portal(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'sinhVien': {
                'MaSinhVien': '1',
                'HoTen': 'Student',
                'LopSinhVien': 'Test',
                'DiDong': '0900000000',
              },
            }),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 700),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: InfoScreen(
              session: Session(
                id: '1',
                fullName: 'Student',
                token: 'test',
                expire: DateTime(2030),
              ),
              portal: portal,
              onLogout: () {},
              onGo: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Học phần'), 300);
      expect(find.text('Học phần'), findsOneWidget);
      expect(find.text('Cài đặt'), findsOneWidget);
      expect(find.text('Thời khoá biểu'), findsOneWidget);
      expect(find.text('Di động'), findsNothing);
      await tester.scrollUntilVisible(find.text('Thông tin sinh viên'), 300);
      await tester.tap(find.text('Thông tin sinh viên'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Di động'), 300);
      expect(find.text('Di động'), findsOneWidget);
    });
  }
}
