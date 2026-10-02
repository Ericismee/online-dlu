import 'package:dlu_tkb/update_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

/// Mở app mà có bản mới thì hiện hộp thoại một lần — bấm Huỷ cho nó khỏi
/// che mất thẻ mà các test dưới đang tìm.
Future<void> dongHopThoai(WidgetTester t) async {
  while (find.text('Huỷ').evaluate().isNotEmpty) {
    await t.tap(find.text('Huỷ'));
    await t.pumpAndSettle();
  }
}

void main() {
  setUp(dungDbTam);

  testWidgets('vô app có bản mới thì hiện hộp thoại, chỉ một lần mỗi bản', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(home: UpdateBanner(check: () async => '1.0.2')),
    );
    await t.pumpAndSettle();
    expect(find.text('Có bản mới v1.0.2'), findsOneWidget);
    await dongHopThoai(t);

    // Mở lại cùng bản đó: thẻ còn, hộp thoại thì thôi.
    await t.pumpWidget(
      MaterialApp(
        home: UpdateBanner(key: const Key('2'), check: () async => '1.0.2'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Có bản mới v1.0.2'), findsNothing);
    expect(find.textContaining('1.0.2'), findsOneWidget);
  });

  testWidgets('có bản mới thì hiện thẻ, không có thì im', (t) async {
    await t.pumpWidget(
      MaterialApp(home: UpdateBanner(check: () async => '1.0.2')),
    );
    await t.pumpAndSettle();
    await dongHopThoai(t);
    expect(find.textContaining('1.0.2'), findsOneWidget);
  });

  testWidgets('có changelog thì dán luôn vào thẻ, không có thì vẫn báo', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: UpdateBanner(
          check: () async => '1.0.2',
          notes: (v) async => 'Thêm mục Cải thiện.',
        ),
      ),
    );
    await t.pumpAndSettle();
    await dongHopThoai(t);
    expect(find.text('Thêm mục Cải thiện.'), findsOneWidget);

    // Mạng hỏng hay lc.json chưa kịp cập nhật: thẻ vẫn phải báo có bản mới.
    await t.pumpWidget(
      MaterialApp(
        home: UpdateBanner(
          key: const Key('2'),
          check: () async => '1.0.3',
          notes: (v) async => null,
        ),
      ),
    );
    await t.pumpAndSettle();
    await dongHopThoai(t);
    expect(find.textContaining('1.0.3'), findsOneWidget);
  });

  testWidgets('kéo thẻ khỏi màn rồi quay lại thì không dựng lại từ đầu', (
    t,
  ) async {
    // Dựng lại là thẻ cao 0 một nhịp rồi phình ra, cả trang nhảy ngược lên.
    var lan = 0;
    await t.pumpWidget(
      MaterialApp(
        home: ListView(
          children: [
            UpdateBanner(
              check: () async {
                lan++;
                return '1.0.2';
              },
              notes: (v) async => null,
            ),
            const SizedBox(height: 3000),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    await dongHopThoai(t);
    expect(lan, 1);

    await t.drag(find.byType(ListView), const Offset(0, -2000));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView), const Offset(0, 2000));
    await t.pumpAndSettle();
    expect(lan, 1);
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
    await dongHopThoai(t);
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

  testWidgets('màn Cập nhật liệt kê mọi bản, mới nhất lên đầu', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: ChangelogScreen(
          check: () async => '1.0.8',
          lichSu: () async => const [
            (version: '1.0.8', date: '2026-10-02', text: 'Màn Cập nhật.'),
            (version: '1.0.7', date: '2026-10-01', text: 'Kéo thả menu.'),
          ],
        ),
      ),
    );
    // Nền giấy có hiệu ứng chạy mãi nên pumpAndSettle treo, pump tay là đủ.
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('v1.0.8'), findsOneWidget);
    expect(find.text('Kéo thả menu.'), findsOneWidget);
    // Có bản mới thì thẻ tải về nằm trên cùng.
    expect(find.textContaining('bấm để tải'), findsOneWidget);
  });
}
