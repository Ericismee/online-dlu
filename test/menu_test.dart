import 'package:dlu_tkb/main.dart';
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

  testWidgets('menu là danh mục, mở ra mới thấy từng mục', (t) async {
    var toi = -1;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuCard(onGo: (i) => toi = i, session: phien),
        ),
      ),
    );
    // Trang chủ chỉ có ba dòng danh mục, không có mười một mục phẳng.
    for (final ten in ['Học tập', 'Kết quả', 'Cá nhân']) {
      expect(find.text(ten), findsOneWidget);
    }
    expect(find.text('Chương trình đào tạo'), findsNothing);

    await t.tap(find.text('Học tập'));
    await t.pumpAndSettle();
    expect(find.text('Chương trình đào tạo'), findsOneWidget);
    expect(find.text('Kết quả'), findsNothing);

    // Mục của thanh dưới: đóng màn danh mục rồi chuyển tab.
    await t.tap(find.text('Thời khoá biểu'));
    await t.pumpAndSettle();
    expect(toi, 0);
    expect(find.text('Học tập'), findsOneWidget);
    expect(find.text('Chương trình đào tạo'), findsNothing);
  });

  test('mỗi mục chỉ nằm trong một danh mục', () {
    final tab = [
      for (final d in MenuCard.danhMuc)
        for (final m in d.$4) m.$1,
    ];
    expect(tab.toSet(), hasLength(tab.length));
  });
}
