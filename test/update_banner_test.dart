import 'package:dlu_tkb/update_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('có bản mới thì hiện thẻ, không có thì im', (t) async {
    await t.pumpWidget(
      MaterialApp(home: UpdateBanner(check: () async => '1.0.2')),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('1.0.2'), findsOneWidget);
  });

  testWidgets('đã mới nhất rồi thì không hiện gì', (t) async {
    await t.pumpWidget(
      MaterialApp(home: UpdateBanner(check: () async => null)),
    );
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.rocket_launch_rounded), findsNothing);
  });

  testWidgets('bấm tắt thì biến mất, mở lại không nhắc bản đã bỏ qua', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(home: UpdateBanner(check: () async => '1.0.2')),
    );
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.close_rounded));
    await t.pumpAndSettle();
    expect(find.textContaining('1.0.2'), findsNothing);

    // Mở lại app (widget mới, key khác cho khỏi bị Flutter tái dùng State
    // cũ), cùng bản đó thì khỏi nhắc lại.
    await t.pumpWidget(
      MaterialApp(
        home: UpdateBanner(key: const Key('2'), check: () async => '1.0.2'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('1.0.2'), findsNothing);

    // Nhưng có bản khác thì vẫn phải báo.
    await t.pumpWidget(
      MaterialApp(
        home: UpdateBanner(key: const Key('3'), check: () async => '1.0.3'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('1.0.3'), findsOneWidget);
  });
}
