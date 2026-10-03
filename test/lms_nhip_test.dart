import 'package:dlu_tkb/lms.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LmsNhip.khoang = () => const Duration(milliseconds: 5));
  tearDown(() {
    LmsNhip.khoang = () => const Duration(seconds: 90);
  });

  /// Chờ đủ vài nhịp; nhịp test chỉ 5ms nên không tốn gì.
  Future<void> choNhip() => Future.delayed(const Duration(milliseconds: 40));

  test('gọi lại nhiều lượt, nhiều nơi nghe cùng một nhịp', () async {
    var a = 0, b = 0;
    Future<void> motA() async => a++;
    Future<void> motB() async => b++;
    LmsNhip.them(motA);
    LmsNhip.them(motB);
    await choNhip();
    LmsNhip.bo(motA);
    LmsNhip.bo(motB);

    expect(a, greaterThan(1));
    // Cùng nhịp nên hai bên đi sát nhau; lệch nhiều nhất một lượt, là lúc
    // nhịp dừng ngay giữa hai lời gọi.
    expect(a - b, inInclusiveRange(0, 1));
  });

  test('bỏ nghe là thôi gọi', () async {
    var a = 0;
    Future<void> mot() async => a++;
    LmsNhip.them(mot);
    await choNhip();
    LmsNhip.bo(mot);
    final luc = a;
    await choNhip();
    expect(a, luc);
  });

  test('ngay() gọi liền, không chờ hết nhịp', () async {
    // Nhịp dài hơn cả bài test: cái gì chạy được cũng chỉ do ngay().
    LmsNhip.khoang = () => const Duration(minutes: 5);
    var a = 0;
    Future<void> mot() async => a++;
    LmsNhip.them(mot);
    await LmsNhip.ngay();
    LmsNhip.bo(mot);
    expect(a, 1);
  });

  test('một nơi nổ lỗi không làm đứng nhịp của nơi khác', () async {
    var b = 0;
    Future<void> no() async => throw Exception('hỏng');
    Future<void> motB() async => b++;
    LmsNhip.them(no);
    LmsNhip.them(motB);
    await choNhip();
    LmsNhip.bo(no);
    LmsNhip.bo(motB);
    expect(b, greaterThan(1));
  });
}
