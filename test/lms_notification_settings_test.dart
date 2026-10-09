import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/nhac.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:dlu_tkb/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

void main() {
  setUp(() async {
    await dungDbTam();
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('điểm danh nằm trong LMS, không phụ thuộc nhắc giờ học', (
    tester,
  ) async {
    await Nhac.datBat(false);
    await Nhac.datDiemDanhBat(true);

    Future<void> moCaiDat() async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            session: Session(
              id: '1',
              fullName: 'Student',
              token: 'test',
              expire: DateTime(2030),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await moCaiDat();
    expect(find.text('Kết nối LMS'), findsOneWidget);
    expect(find.text('Nhắc giờ học'), findsOneWidget);
    expect(find.text('Nhắc điểm danh'), findsNothing);

    await LmsVault.save('test', 'test');
    await Settings.datLmsBat(true);
    await tester.pumpWidget(const SizedBox());
    await moCaiDat();

    expect(find.text('Nhắc điểm danh'), findsOneWidget);
    expect(find.text('Nhắc giờ học'), findsOneWidget);
    expect(await Nhac.bat(), isFalse);
    expect(await Nhac.diemDanhBat(), isTrue);
    expect(
      tester.getTopLeft(find.text('Nhắc điểm danh')).dy,
      lessThan(tester.getTopLeft(find.text('Nhắc giờ học')).dy),
    );
  });
}
