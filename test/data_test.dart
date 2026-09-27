import 'package:dlu_tkb/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toNum nhận cả số lẫn chuỗi', () {
    expect(toNum(4), 4);
    expect(toNum('3'), 3);
    expect(toNum(null), 0);
    expect(toNum('x'), 0);
  });

  test('clean gỡ thẻ html và ký tự escape', () {
    expect(clean('<span>Thiết kế Web</span>'), 'Thiết kế Web');
    expect(clean('Toán<br/>rời rạc'), 'Toán rời rạc');
    expect(clean('Lập trình &amp; ứng dụng&nbsp;'), 'Lập trình & ứng dụng');
    expect(clean(null), '');
  });
}
