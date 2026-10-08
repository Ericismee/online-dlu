import 'package:dlu_tkb/custom_lich.dart';
import 'package:dlu_tkb/db.dart';
import 'package:dlu_tkb/graph.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

void main() {
  setUp(dungDbTam);

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

  test(
    'chỉ số lạc (-1, quá tầm) thì bỏ qua, không nổ cũng không sửa nhầm',
    () async {
      final d = DateTime(2026, 9, 29);
      await CustomLichStore.add(d, const CustomLich(tieuDe: 'A', batDau: 420));
      await CustomLichStore.remove(d, -1);
      await CustomLichStore.remove(d, 9);
      await CustomLichStore.update(
        d,
        -1,
        const CustomLich(tieuDe: 'X', batDau: 0),
      );
      final list = await CustomLichStore.forDay(d);
      expect(list, hasLength(1));
      expect(list.first.tieuDe, 'A');
    },
  );

  test('giờ về đặt trước giờ đi thì bị kéo về bằng giờ đi', () async {
    final d = DateTime(2026, 9, 29);
    await CustomLichStore.add(
      d,
      const CustomLich(tieuDe: 'Ngược', batDau: 9 * 60, ketThuc: 7 * 60),
    );
    expect((await CustomLichStore.forDay(d)).first.ketThuc, 9 * 60);
    // Khoảng giờ không còn lật ngược nên cảnh báo đụng giờ mới tính đúng.
    final c = (await CustomLichStore.forDay(d)).first;
    expect(trungGioChinhQuy(c, const []), isFalse);
  });

  test('cùng giờ thì lịch chính quy đứng trước lịch tự đặt', () {
    const rieng = CustomLich(tieuDe: 'Lên ATC', batDau: 7 * 60 + 30);
    final tiet = {'BeginTime': 'Tiết 1', 'EndTime': 'Tiết 2'};
    // Đảo thứ tự đầu vào mà kết quả vẫn y nhau mới là sắp xếp chốt được.
    expect(ganLichTrongNgay([tiet], [rieng]).last, same(rieng));
    expect(ganLichTrongNgay([tiet], [rieng]).first, same(tiet));
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

  group('lặp hàng tuần', () {
    // 2026-09-29 là thứ ba.
    final batDau = DateTime(2026, 9, 29);

    Future<void> datLap() => CustomLichStore.add(
      batDau,
      const CustomLich(
        tieuDe: 'Lên ATC',
        batDau: 7 * 60,
        ketThuc: 9 * 60,
        lap: {DateTime.tuesday, DateTime.thursday},
      ),
    );

    test('rơi đúng những thứ đã chọn, không đụng thứ khác', () async {
      await datLap();
      expect(await CustomLichStore.forDay(batDau), hasLength(1));
      // Thứ năm cùng tuần và thứ ba tuần sau đều có.
      expect(await CustomLichStore.forDay(DateTime(2026, 10, 1)), hasLength(1));
      expect(await CustomLichStore.forDay(DateTime(2026, 10, 6)), hasLength(1));
      // Thứ tư thì không.
      expect(await CustomLichStore.forDay(DateTime(2026, 9, 30)), isEmpty);
      // Trước ngày đặt cũng không — lặp chỉ chạy từ hôm đặt trở đi.
      expect(await CustomLichStore.forDay(DateTime(2026, 9, 22)), isEmpty);
    });

    test('dừng sau ngày hết hạn lặp', () async {
      await CustomLichStore.add(
        batDau,
        CustomLich(
          tieuDe: 'Ôn thi',
          batDau: 19 * 60,
          lap: const {DateTime.tuesday},
          denNgay: DateTime(2026, 10, 6),
        ),
      );
      expect(await CustomLichStore.forDay(DateTime(2026, 10, 6)), hasLength(1));
      expect(await CustomLichStore.forDay(DateTime(2026, 10, 13)), isEmpty);
    });

    test('xoá một buổi chỉ mất buổi đó, tuần sau vẫn còn', () async {
      await datLap();
      await CustomLichStore.remove(DateTime(2026, 10, 1), 0);
      expect(await CustomLichStore.forDay(DateTime(2026, 10, 1)), isEmpty);
      expect(await CustomLichStore.forDay(DateTime(2026, 10, 6)), hasLength(1));
      expect(await CustomLichStore.forDay(batDau), hasLength(1));
    });

    test('sửa một buổi chỉ đổi buổi đó', () async {
      await datLap();
      await CustomLichStore.update(
        DateTime(2026, 10, 1),
        0,
        const CustomLich(tieuDe: 'Lên ATC', batDau: 13 * 60),
      );
      expect(
        (await CustomLichStore.forDay(DateTime(2026, 10, 1))).first.batDau,
        13 * 60,
      );
      expect(
        (await CustomLichStore.forDay(DateTime(2026, 10, 6))).first.batDau,
        7 * 60,
      );
    });

    test(
      'xoá cả chuỗi thì không còn buổi nào, mà dòng vẫn nằm trong máy',
      () async {
        await datLap();
        await CustomLichStore.xoaChuoi(batDau, 0);
        expect(await CustomLichStore.forDay(batDau), isEmpty);
        expect(await CustomLichStore.forDay(DateTime(2026, 10, 6)), isEmpty);
        final con = await Db.i.select(Db.i.lichRiengs).get();
        expect(con, hasLength(1));
        expect(con.first.bat, isFalse);
      },
    );

    test('lịch tháng thấy đủ các buổi lặp', () async {
      await datLap();
      final thang = await CustomLichStore.forMonth(DateTime(2026, 10));
      // Tháng 10/2026: thứ ba 6,13,20,27 và thứ năm 1,8,15,22,29.
      expect(thang.keys.toSet(), {1, 6, 8, 13, 15, 20, 22, 27, 29});
    });
  });

  test(
    'mẫu nhanh lấy lần đặt gần nhất cùng tên, không phân biệt hoa thường',
    () async {
      await CustomLichStore.add(
        DateTime(2026, 9, 1),
        const CustomLich(tieuDe: 'Lên ATC', batDau: 420, viTri: 'P301'),
      );
      await CustomLichStore.add(
        DateTime(2026, 9, 8),
        const CustomLich(
          tieuDe: 'Lên ATC',
          batDau: 13 * 60,
          ketThuc: 15 * 60,
          mau: 0xFFA5DCFF,
          viTri: 'P401',
        ),
      );
      final mau = await CustomLichStore.mauGanNhat('  lên atc ');
      expect(mau, isNotNull);
      expect(mau!.batDau, 13 * 60);
      expect(mau.ketThuc, 15 * 60);
      expect(mau.mau, 0xFFA5DCFF);
      expect(mau.viTri, 'P401');
      expect(await CustomLichStore.mauGanNhat('chưa từng đặt'), isNull);
    },
  );
}
