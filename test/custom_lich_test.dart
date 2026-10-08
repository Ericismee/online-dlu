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

  test('xoá đúng dòng theo id, không đụng mục khác', () async {
    final d = DateTime(2026, 9, 29);
    await CustomLichStore.add(d, const CustomLich(tieuDe: 'A', batDau: 420));
    await CustomLichStore.add(d, const CustomLich(tieuDe: 'B', batDau: 480));
    await CustomLichStore.remove(
      d,
      (await CustomLichStore.forDay(d)).first.id!,
    );
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
    'id không có trong ngày thì bỏ qua, không nổ cũng không sửa nhầm',
    () async {
      final d = DateTime(2026, 9, 29);
      await CustomLichStore.add(d, const CustomLich(tieuDe: 'A', batDau: 420));
      // Dòng của ngày khác cũng là id lạc với ngày này.
      await CustomLichStore.add(
        DateTime(2026, 9, 30),
        const CustomLich(tieuDe: 'Khác', batDau: 420),
      );
      final idNgayKhac = (await CustomLichStore.forDay(DateTime(2026, 9, 30)))
          .first
          .id!;
      await CustomLichStore.remove(d, idNgayKhac);
      await CustomLichStore.remove(d, 9999);
      await CustomLichStore.update(
        d,
        idNgayKhac,
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

  test('update ghi đè đúng dòng theo id, không đụng mục khác', () async {
    final d = DateTime(2026, 9, 29);
    await CustomLichStore.add(d, const CustomLich(tieuDe: 'A', batDau: 420));
    await CustomLichStore.add(d, const CustomLich(tieuDe: 'B', batDau: 480));
    await CustomLichStore.update(
      d,
      (await CustomLichStore.forDay(d)).first.id!,
      const CustomLich(tieuDe: 'A', batDau: 420, ketThuc: 500),
    );
    final list = await CustomLichStore.forDay(d);
    expect(list[0].ketThuc, 500);
    expect(list[1].tieuDe, 'B');
  });

  test('hai mục giống hệt nhau thì vẫn xoá đúng dòng người bấm', () async {
    final d = DateTime(2026, 9, 29);
    const c = CustomLich(tieuDe: 'Ôn', batDau: 420, ketThuc: 480);
    await CustomLichStore.add(d, c);
    await CustomLichStore.add(d, c);
    final ds = await CustomLichStore.forDay(d);
    await CustomLichStore.remove(d, ds.last.id!);
    final con = await CustomLichStore.forDay(d);
    expect(con, hasLength(1));
    expect(con.first.id, ds.first.id);
  });

  test('ngày dừng lặp trước cả ngày đặt thì kéo về ngày đặt', () async {
    final d = DateTime(2026, 9, 29);
    await CustomLichStore.add(
      d,
      CustomLich(
        tieuDe: 'Ôn thi',
        batDau: 19 * 60,
        lap: const {DateTime.tuesday},
        denNgay: DateTime(2026, 9, 1),
      ),
    );
    // Không im lặng mất tích: buổi đầu vẫn thấy, tuần sau thì hết.
    expect(await CustomLichStore.forDay(d), hasLength(1));
    expect(await CustomLichStore.forDay(DateTime(2026, 10, 6)), isEmpty);
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
      final ngay = DateTime(2026, 10, 1);
      await CustomLichStore.remove(
        ngay,
        (await CustomLichStore.forDay(ngay)).first.id!,
      );
      expect(await CustomLichStore.forDay(DateTime(2026, 10, 1)), isEmpty);
      expect(await CustomLichStore.forDay(DateTime(2026, 10, 6)), hasLength(1));
      expect(await CustomLichStore.forDay(batDau), hasLength(1));
    });

    test('sửa một buổi chỉ đổi buổi đó', () async {
      await datLap();
      final ngay = DateTime(2026, 10, 1);
      await CustomLichStore.update(
        ngay,
        (await CustomLichStore.forDay(ngay)).first.id!,
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
        await CustomLichStore.xoaChuoi(
          batDau,
          (await CustomLichStore.forDay(batDau)).first.id!,
        );
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

    test('đọc nhiều ngày một lượt, vắt qua đầu tháng vẫn đúng', () async {
      await datLap();
      final ds = await CustomLichStore.forRange(DateTime(2026, 9, 28), 7);
      // 29/9 thứ ba, 1/10 thứ năm; ngày trống thì không có khoá.
      expect(ds.keys.toList(), [DateTime(2026, 9, 29), DateTime(2026, 10, 1)]);
      expect(ds[DateTime(2026, 10, 1)], hasLength(1));
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

  test('mục bỏ ngỏ giờ về không chắn mục đang chạy', () {
    const moNgo = CustomLich(tieuDe: 'Lên ATC', batDau: 7 * 60);
    const ca = CustomLich(
      tieuDe: 'Ca chiều',
      batDau: 14 * 60,
      ketThuc: 16 * 60,
    );
    final now = DateTime(2026, 9, 29, 15, 0);
    // 15h đang trong ca 14h-16h: thẻ phải chỉ vào ca đó, chứ không phải buổi
    // sáng chưa ai bấm xong.
    expect(ketiepRieng(const [moNgo, ca], now)?.tieuDe, 'Ca chiều');
    // Ca tan rồi thì mới tới lượt mục bỏ ngỏ.
    expect(
      ketiepRieng(const [moNgo, ca], DateTime(2026, 9, 29, 17, 0))?.tieuDe,
      'Lên ATC',
    );
    // Chưa tới giờ nào thì lấy cái sớm nhất.
    expect(
      ketiepRieng(const [ca, moNgo], DateTime(2026, 9, 29, 6, 0))?.tieuDe,
      'Lên ATC',
    );
    // Xong hết thì không còn gì để nhắc.
    expect(ketiepRieng(const [ca], DateTime(2026, 9, 29, 18, 0)), isNull);
  });

  test('buổi đầu của mục lặp rơi đúng ngày gần nhất phía sau', () {
    // 30/9/2026 là thứ tư; lặp T2 thì buổi đầu là 5/10.
    expect(
      buoiDau(DateTime(2026, 9, 30), const {DateTime.monday}),
      DateTime(2026, 10, 5),
    );
    // Thứ của chính ngày đặt nằm trong danh sách thì buổi đầu là hôm đó.
    expect(
      buoiDau(DateTime(2026, 9, 30), const {DateTime.wednesday}),
      DateTime(2026, 9, 30),
    );
    expect(buoiDau(DateTime(2026, 9, 30), const {}), isNull);
  });
}
