import 'package:dlu_tkb/main.dart';
import 'package:dlu_tkb/log_screen.dart';
import 'package:dlu_tkb/nhat_ky.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

final phien = Session(
  id: '2312577',
  fullName: 'Nguyễn Văn A',
  token: 't',
  expire: DateTime(2030),
);

void main() {
  setUp(dungDbTam);

  testWidgets('mọi mục nằm sẵn trên Trang chủ, bấm một lần là tới', (t) async {
    var toi = -1;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MenuCard(onGo: (i) => toi = i, session: phien),
          ),
        ),
      ),
    );
    // Không phải mở thêm màn nào: tên danh mục và mọi mục cùng hiện một lúc.
    for (final ten in [
      'Học tập',
      'Kết quả',
      'Cá nhân',
      'Chương trình đào tạo',
    ]) {
      expect(find.text(ten), findsOneWidget);
    }

    await t.tap(find.text('Thời khoá biểu'));
    await t.pumpAndSettle();
    expect(toi, 0);
  });

  testWidgets('mục Log chỉ hiện khi bật chế độ nhà phát triển', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MenuCard(onGo: (_) {}, session: phien),
          ),
        ),
      ),
    );
    expect(find.text('Log'), findsNothing);

    NhatKy.bat = true;
    await t.pumpAndSettle();
    expect(find.text('Log'), findsOneWidget);

    // Bấm vô phải ra sổ verbose, chứ nhánh thiếu trong switch là nó lặng lẽ
    // mở Chương trình đào tạo.
    await t.tap(find.text('Log'));
    await t.pumpAndSettle();
    expect(find.byType(LogScreen), findsOneWidget);
    Navigator.of(t.element(find.byType(LogScreen))).pop();
    await t.pumpAndSettle();
    NhatKy.bat = false;
    await t.pumpAndSettle();
    expect(find.text('Log'), findsNothing);
  });

  test('mỗi mục chỉ nằm trong một danh mục', () {
    final tab = [
      for (final d in MenuCard.danhMuc)
        for (final m in d.$4) m.$1,
    ];
    expect(tab.toSet(), hasLength(tab.length));
  });
}
