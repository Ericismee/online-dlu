import 'package:dlu_tkb/curriculum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('byTerm gộp theo học kỳ, credits cộng tín chỉ', () {
    final rows = [
      {'HocKy': 'Học kỳ 5', 'STC': 4},
      {'HocKy': 'Học kỳ 5', 'STC': 3},
      {'HocKy': 'Học kỳ 6', 'STC': 2},
    ];
    final groups = byTerm(rows);
    expect(groups.map((g) => g.$1).toList(), ['Học kỳ 5', 'Học kỳ 6']);
    expect(credits(groups.first.$2), 7);
    expect(credits(rows), 9);
  });
}
