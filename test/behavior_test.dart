import 'package:dlu_tkb/behavior.dart';
import 'package:dlu_tkb/paper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scoreColor theo thang xếp loại', () {
    expect(scoreColor(95), Paper.mint);
    expect(scoreColor(80), Paper.sun);
    expect(scoreColor(73), Paper.peach);
    expect(scoreColor(50), Paper.rose);
  });
}
