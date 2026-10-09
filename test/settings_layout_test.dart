import 'package:dlu_tkb/portal.dart';
import 'package:dlu_tkb/settings.dart';
import 'package:dlu_tkb/login.dart';
import 'package:dlu_tkb/main.dart' hide MenuCard;
import 'package:dlu_tkb/menu.dart';
import 'package:dlu_tkb/nhac.dart';
import 'package:dlu_tkb/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

void main() {
  for (final width in [280.0, 320.0, 360.0, 400.0]) {
    testWidgets('app tabs fit ${width.toInt()}dp with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 2100);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({});
      await dungDbTam();
      final session = Session(
        id: '1',
        fullName: 'Student',
        token: 'test',
        expire: DateTime(2030),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 700),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: Shell(session: session, onLogout: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      for (final tab in [0, 1, 3, 4, 2]) {
        tester.widget<PaperBar>(find.byType(PaperBar)).onTap(tab);
        await tester.pump(const Duration(milliseconds: 400));
        final error = tester.takeException();
        expect(error, isNull, reason: '$error; tab $tab at $width dp');
      }
      await tester.pumpWidget(const SizedBox());
      Clock.instance.stop();
    });
    testWidgets('settings fit ${width.toInt()}dp with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 2100);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({});
      await dungDbTam();
      await Nhac.datBat(true);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 700),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: SettingsScreen(
              session: Session(
                id: '1',
                fullName: 'Student',
                token: 'test',
                expire: DateTime(2030),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (var index = 0; index < 6; index++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -550));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'scroll $index at $width dp',
        );
      }
    });
    testWidgets('login fits ${width.toInt()}dp with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 2100);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 700),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: LoginScreen(onLoggedIn: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('menu fits ${width.toInt()}dp with large text', (tester) async {
      tester.view.physicalSize = Size(width * 3, 2100);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 700),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: MenuCard(
                  onGo: (_) {},
                  session: Session(
                    id: '1',
                    fullName: 'Student',
                    token: 'test',
                    expire: DateTime(2030),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
