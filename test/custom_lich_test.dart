import 'package:dlu_tkb/custom_lich.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('thêm rồi đọc lại đúng ngày, ngày khác vẫn trống', () async {
    final d = DateTime(2026, 9, 29);
    await CustomLichStore.add(
      d,
      const CustomLich(tieuDe: 'Lên ATC', batDau: 7 * 60, ketThuc: 9 * 60),
    );
    final list = await CustomLichStore.forDay(d);
    expect(list, hasLength(1));
    expect(list.first.tieuDe, 'Lên ATC');
    expect(list.first.ketThuc, 9 * 60);
    expect(await CustomLichStore.forDay(DateTime(2026, 9, 30)), isEmpty);
  });

  test('giờ về tuỳ chọn để trống vẫn lưu được', () async {
    final d = DateTime(2026, 9, 29);
    await CustomLichStore.add(d, const CustomLich(tieuDe: 'ATC', batDau: 420));
    expect((await CustomLichStore.forDay(d)).first.ketThuc, isNull);
  });

  test('xoá đúng mục theo chỉ số, không đụng mục khác', () async {
    final d = DateTime(2026, 9, 29);
    await CustomLichStore.add(d, const CustomLich(tieuDe: 'A', batDau: 420));
    await CustomLichStore.add(d, const CustomLich(tieuDe: 'B', batDau: 480));
    await CustomLichStore.remove(d, 0);
    final list = await CustomLichStore.forDay(d);
    expect(list, hasLength(1));
    expect(list.first.tieuDe, 'B');
  });
}
