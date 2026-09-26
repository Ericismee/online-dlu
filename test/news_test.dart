import 'package:dlu_tkb/news.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unread counts IsRead == 0', () {
    expect(
      unread([
        {'IsRead': 0},
        {'IsRead': 1},
        {'IsRead': 0},
      ]),
      2,
    );
  });
}
