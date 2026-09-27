import 'package:dlu_tkb/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toNum nhận cả số lẫn chuỗi', () {
    expect(toNum(4), 4);
    expect(toNum('3'), 3);
    expect(toNum(null), 0);
    expect(toNum('x'), 0);
  });

  test('dấu sao = học phần điều kiện', () {
    expect(isCondition('Giáo dục thể chất 1 (Thực hành) *'), isTrue);
    expect(subjectName('Giáo dục thể chất 1 *'), 'Giáo dục thể chất 1');
    expect(isCondition('Thiết kế Web'), isFalse);
    expect(subjectName('Thiết kế Web'), 'Thiết kế Web');
  });

  test('clean gỡ thẻ html và ký tự escape', () {
    expect(clean('<span>Thiết kế Web</span>'), 'Thiết kế Web');
    expect(clean('Toán<br/>rời rạc'), 'Toán rời rạc');
    expect(clean('Lập trình &amp; ứng dụng&nbsp;'), 'Lập trình & ứng dụng');
    expect(clean(null), '');
  });

  test('nhãn dữ liệu: cùng ngày chỉ hiện giờ, khác ngày thêm ngày', () {
    final now = DateTime(2026, 9, 27, 13, 5);
    expect(dataAge(DateTime(2026, 9, 27, 13, 2), now), 'Dữ liệu lúc 13:02');
    expect(dataAge(DateTime(2026, 9, 26, 9, 40), now), 'Dữ liệu 26/9 lúc 9:40');
  });

  test('tìm không dấu', () {
    expect(khop('Toán rời rạc', 'toan roi'), isTrue);
    expect(khop('Toán rời rạc', 'TOAN'), isTrue);
    expect(khop('Đại số', 'dai so'), isTrue);
    expect(khop('Toán rời rạc', 'ly'), isFalse);
    // Ô trống thì đừng lọc mất gì.
    expect(khop('bất kỳ', '   '), isTrue);
  });
}
