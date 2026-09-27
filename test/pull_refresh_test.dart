import 'dart:async';

import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('kéo ngược lên là tắt vòng xoay, không chờ hết lượt làm mới', (
    t,
  ) async {
    final cham = Completer<void>();
    Future<void> reloader() => cham.future;
    Cache.refreshers.add(reloader);
    addTearDown(() {
      Cache.refreshers.remove(reloader);
      if (!cham.isCompleted) cham.complete();
    });

    await t.pumpWidget(
      MaterialApp(
        home: PullRefresh(
          child: ListView(
            children: [for (var i = 0; i < 30; i++) SizedBox(height: 80)],
          ),
        ),
      ),
    );

    await t.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    // Đổi ý: kéo ngược lên. Lượt làm mới vẫn chưa xong mà vòng xoay phải tắt.
    await t.drag(find.byType(ListView), const Offset(0, -200));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(cham.isCompleted, isFalse, reason: 'lượt làm mới vẫn đang chạy');
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });
}
