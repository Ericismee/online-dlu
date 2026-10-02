import 'package:dlu_tkb/custom_lich.dart';
import 'package:dlu_tkb/graph.dart';
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

  test(
    'màu và vị trí lưu đọc lại đúng, không đặt thì có màu mặc định',
    () async {
      final d = DateTime(2026, 9, 29);
      await CustomLichStore.add(
        d,
        const CustomLich(
          tieuDe: 'ATC',
          batDau: 420,
          mau: 0xFFA5DCFF,
          viTri: 'P301',
        ),
      );
      await CustomLichStore.add(
        d,
        const CustomLich(tieuDe: 'Khác', batDau: 480),
      );
      final list = await CustomLichStore.forDay(d);
      expect(list[0].mau, 0xFFA5DCFF);
      expect(list[0].viTri, 'P301');
      expect(list[1].mau, customLichMauMacDinh);
      expect(list[1].viTri, isNull);
    },
  );

  test('xongLuc chỉ chốt giờ về, giữ nguyên màu và vị trí', () {
    const c = CustomLich(
      tieuDe: 'ATC',
      batDau: 420,
      mau: 0xFFA5DCFF,
      viTri: 'P301',
    );
    final xong = c.xongLuc(515);
    expect(xong.ketThuc, 515);
    expect(xong.mau, 0xFFA5DCFF);
    expect(xong.viTri, 'P301');
    expect(xong.tieuDe, 'ATC');
    expect(xong.batDau, 420);
    // Chốt rồi là không còn "đang diễn ra" nữa.
    expect(
      customLessonNow(xong, DateTime(2026, 9, 29, 8, 40))?.pha,
      LessonPhase.xong,
    );
  });

  test('update ghi đè đúng mục theo chỉ số, không đụng mục khác', () async {
    final d = DateTime(2026, 9, 29);
    await CustomLichStore.add(d, const CustomLich(tieuDe: 'A', batDau: 420));
    await CustomLichStore.add(d, const CustomLich(tieuDe: 'B', batDau: 480));
    await CustomLichStore.update(
      d,
      0,
      const CustomLich(tieuDe: 'A', batDau: 420, ketThuc: 500),
    );
    final list = await CustomLichStore.forDay(d);
    expect(list[0].ketThuc, 500);
    expect(list[1].tieuDe, 'B');
  });
}
