import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dlu_tkb/paper.dart';

/// Tỉ lệ tương phản theo WCAG 2.1.
double tuongPhan(Color a, Color b) {
  double sang(Color c) {
    double k(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * k(c.r) + 0.7152 * k(c.g) + 0.0722 * k(c.b);
  }

  final (x, y) = (sang(a), sang(b));
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  test('các cặp màu chữ của bộ giấy đạt AA 4.5:1', () {
    // Đổi accent, ink2 hay nền kem là test này đổ — đúng ý: PRODUCT.md ghi
    // AA cho chữ thường là yêu cầu, không phải mong muốn.
    for (final (ten, chu, nen) in [
      ('ink trên giấy', Paper.ink, Paper.paper),
      ('ink trên thẻ', Paper.ink, Paper.card),
      ('ink trên cam', Paper.ink, Paper.accent),
      ('ink2 trên giấy', Paper.ink2, Paper.paper),
      ('ink2 trên thẻ', Paper.ink2, Paper.card),
      for (final (tenNen, mau) in [
        ('nắng', Paper.sun),
        ('hồng', Paper.rose),
        ('trời', Paper.sky),
        ('đào', Paper.peach),
        ('bạc hà', Paper.mint),
      ])
        ('ink trên $tenNen', Paper.ink, mau),
    ]) {
      expect(tuongPhan(chu, nen), greaterThanOrEqualTo(4.5), reason: ten);
    }
  });

  test('chữ kem hay giấy trên nền cam là dưới chuẩn, đừng dùng lại', () {
    // Ghi lại con số để lần sau ai định đặt chữ sáng lên nền cam thì thấy
    // ngay tại sao mặc định onColor của PaperButton là mực.
    expect(tuongPhan(Paper.card, Paper.accent), lessThan(4.5));
    expect(tuongPhan(Paper.paper, Paper.accent), lessThan(4.5));
  });

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

  testWidgets('ô nhập giấy có nhãn cho trình đọc màn hình', (t) async {
    // Ô nhập không có labelText/hintText nên nhãn phải tới từ Semantics; thiếu
    // nó là VoiceOver đọc ô mật khẩu thành "ô nhập, trống".
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperField(
            nhan: 'Mật khẩu LMS',
            controller: TextEditingController(),
            onSubmit: () {},
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Mật khẩu LMS'), findsOneWidget);
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
