import 'package:dlu_tkb/main.dart';
import 'package:dlu_tkb/paper.dart';
import 'package:dlu_tkb/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

void main() {
  setUp(dungDbTam);
  tearDown(() => Paper.datToi(false));

  test('gạt chế độ tối là cả bảng màu đổi, viền và bóng theo mực mới', () {
    final nenSang = Paper.paper;
    Paper.datToi(true);
    expect(Paper.toi, isTrue);
    expect(Paper.paper, isNot(nenSang));
    // Nền tối, mực sáng — ngược hẳn bảng sáng.
    expect(Paper.paper.computeLuminance(), lessThan(0.2));
    expect(Paper.ink.computeLuminance(), greaterThan(0.6));
    // Viền và bóng cứng phải dựng lại theo mực mới, không thì đen trên đen.
    expect((Paper.border.top).color, Paper.ink);
    expect(Paper.shadow().first.color, Paper.ink);
    // Giấy màu tối đi đủ để mực kem đặt lên vẫn đọc được.
    for (final c in [Paper.sun, Paper.accent, Paper.mint, Paper.sky]) {
      expect(c.computeLuminance(), lessThan(0.4));
    }

    Paper.datToi(false);
    expect(Paper.paper, nenSang);
    expect(Paper.theme().brightness, Brightness.light);
  });

  test('cờ chế độ tối nằm lại trong sổ cài đặt', () async {
    expect(await Settings.toi(), isFalse);
    await Settings.datToi(true);
    expect(await Settings.toi(), isTrue);
  });

  testWidgets('gạt chế độ tối thì cả cây dựng lại, không sót màu cũ', (
    t,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await t.pumpWidget(const App());
    await t.pumpAndSettle();
    final khoa = t.widget<MaterialApp>(find.byType(MaterialApp)).key;

    Paper.datToi(true);
    await t.pumpAndSettle();
    // Khoá đổi là cây dựng lại từ đầu: widget `const` giữ nguyên instance nên
    // không đổi khoá thì Flutter bỏ qua lượt vẽ, nửa màn kẹt lại màu cũ.
    expect(t.widget<MaterialApp>(find.byType(MaterialApp)).key, isNot(khoa));
    const mucSang = Color(0xFF444444);
    expect(
      t
          .widgetList<Text>(find.byType(Text))
          .where((w) => w.style?.color == mucSang),
      isEmpty,
    );
  });
}
