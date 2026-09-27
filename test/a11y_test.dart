import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dlu_tkb/paper.dart';

void main() {
  testWidgets('nút giấy được đọc là button, có nhãn', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperButton(label: 'Đăng nhập', onPressed: () {}),
        ),
      ),
    );
    expect(
      t.getSemantics(find.text('Đăng nhập')),
      matchesSemantics(label: 'Đăng nhập', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('tắt hiệu ứng thì PopIn hiện thẳng, không mờ', (t) async {
    await t.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: PopIn(child: Text('xin chào')),
        ),
      ),
    );
    // Chưa pump thêm frame nào mà chữ đã ở nguyên vẹn.
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('xin chào'), findsOneWidget);
  });
}
