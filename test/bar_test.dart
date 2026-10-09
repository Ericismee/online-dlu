import 'package:dlu_tkb/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [280.0, 320.0, 360.0, 390.0, 600.0]) {
    testWidgets('thanh tab không tràn ở ${width.toInt()}dp', (t) async {
      t.view.physicalSize = Size(width * 3, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (var index = 0; index < 5; index++) {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: PaperBar(index: index, onTap: (_) {}),
              ),
            ),
          ),
        );
        expect(t.takeException(), isNull);
        expect(t.getTopRight(find.text('Hồ sơ')).dx, lessThanOrEqualTo(width));
      }
    });
  }

  testWidgets('chừa đủ chỗ dưới danh sách cho thanh điều hướng', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PaperBar(index: 2, onTap: (_) {}),
          ),
        ),
      ),
    );
    // Đáy ListView của các tab để 110 + safe area.
    expect(t.getSize(find.byType(PaperBar)).height, lessThanOrEqualTo(110));
  });
}
