import 'package:dlu_tkb/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
