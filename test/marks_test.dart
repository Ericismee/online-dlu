import 'package:dlu_tkb/marks.dart';
import 'package:dlu_tkb/paper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('markColor phân biệt đạt / chưa đạt', () {
    expect(markColor({'IsPass': 'x'}), Paper.mint);
    expect(markColor({'IsPass': ''}), Paper.rose);
  });
}
