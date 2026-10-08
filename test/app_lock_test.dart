import 'package:dlu_tkb/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

void main() {
  setUp(() async {
    await dungDbTam();
    FlutterSecureStorage.setMockInitialValues({
      'username': '2312577',
      'password': 'khong-phai-that',
    });
  });

  testWidgets('mở khoá bằng mật khẩu portal, sai thì không vào', (t) async {
    var mo = 0;
    await t.pumpWidget(
      MaterialApp(home: AppLockScreen(onUnlocked: () => mo++)),
    );
    // Sinh trắc học không có trong test (không plugin), màn đứng lại chờ gõ.
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), 'sai');
    await t.tap(find.text('Mở bằng mật khẩu'));
    await t.pumpAndSettle();
    expect(mo, 0);
    expect(find.text('Mật khẩu không đúng'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'khong-phai-that');
    await t.tap(find.text('Mở bằng mật khẩu'));
    await t.pumpAndSettle();
    expect(mo, 1);
  });
}
