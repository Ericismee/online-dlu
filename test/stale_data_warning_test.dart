import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

void main() {
  setUp(dungDbTam);

  tearDown(() => Cache.clear());

  testWidgets('chưa quá 1 ngày thì im, quá rồi thì báo đỏ không tắt được', (
    t,
  ) async {
    final now = DateTime(2026, 10, 2, 12);
    Cache.served['x'] = now.subtract(const Duration(hours: 23));
    await t.pumpWidget(MaterialApp(home: StaleDataWarning(now: now)));
    expect(find.byIcon(Icons.warning_rounded), findsNothing);

    Cache.served['x'] = now.subtract(const Duration(days: 1, minutes: 1));
    await t.pumpWidget(MaterialApp(home: StaleDataWarning(now: now)));
    expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });
}
