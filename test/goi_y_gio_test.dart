import 'dart:math';

import 'package:dlu_tkb/goi_y_gio.dart';
import 'package:dlu_tkb/lin_ucb.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

void main() {
  setUp(() async {
    await dungDbTam();
    GoiYGio.quen();
    // Bốc đồng điểm bằng số ngẫu nhiên cố định, kết quả mới lặp lại được.
    GoiYGio.ngau = Random(7);
  });
  tearDown(() => GoiYGio.ngau = null);

  final sangBanRanh = dacTrungGoiY(
    cuoiTuan: false,
    sang: true,
    chieu: false,
    toi: false,
  );
  final ranhCaNgay = dacTrungGoiY(
    cuoiTuan: true,
    sang: false,
    chieu: false,
    toi: false,
  );

  test('khung giờ và phút quy đổi qua lại khớp nhau', () {
    expect(gioCuaKhung(0), 6 * 60);
    expect(gioCuaKhung(goiYSoKhung - 1), 20 * 60);
    expect(khungCuaGio(gioCuaKhung(3)), 3);
    expect(khungCuaGio(7 * 60 + 30), 0); // 7h30 vẫn thuộc khung 6–8h
    // Ngoài dải thì kẹp vào hai đầu chứ không văng chỉ số.
    expect(khungCuaGio(1 * 60), 0);
    expect(khungCuaGio(23 * 60 + 59), goiYSoKhung - 1);
  });

  test('chốt giờ nào thì lần sau gợi ý đúng khung đó', () async {
    // Mười lần đặt lịch lúc 14h cho ngày sáng bận.
    for (var i = 0; i < 10; i++) {
      final goi = await GoiYGio.goiY(sangBanRanh);
      await GoiYGio.ghiNhan(
        x: sangBanRanh,
        goiYPhut: goi,
        chonPhut: 14 * 60 + 15,
      );
    }
    expect(await GoiYGio.goiY(sangBanRanh), 14 * 60);
  });

  test(
    'ngữ cảnh khác thì gợi ý khác, không bê nguyên thói quen ngày bận',
    () async {
      for (var i = 0; i < 12; i++) {
        await GoiYGio.ghiNhan(
          x: sangBanRanh,
          goiYPhut: 14 * 60,
          chonPhut: 14 * 60,
        );
        await GoiYGio.ghiNhan(
          x: ranhCaNgay,
          goiYPhut: 8 * 60,
          chonPhut: 8 * 60,
        );
      }
      expect(await GoiYGio.goiY(sangBanRanh), 14 * 60);
      expect(await GoiYGio.goiY(ranhCaNgay), 8 * 60);
    },
  );

  test('mô hình nằm trong sổ, mở lại app vẫn nhớ', () async {
    for (var i = 0; i < 10; i++) {
      await GoiYGio.ghiNhan(
        x: sangBanRanh,
        goiYPhut: 6 * 60,
        chonPhut: 16 * 60,
      );
    }
    // Quên bản trong RAM = mở lại app; phải đọc lại được từ SQLite.
    GoiYGio.quen();
    expect(await GoiYGio.goiY(sangBanRanh), 16 * 60);
  });

  test('bản lưu lệch số khung thì bỏ, không ghép bừa vào mô hình mới', () {
    final m = LinUCB(soTay: 3, soChieu: 2);
    m.hoc([1, 0], {1: 1});
    expect(LinUCB.fromJson(m.toJson(), soTay: 3, soChieu: 2), isA<LinUCB>());
    expect(LinUCB.fromJson(m.toJson(), soTay: 4, soChieu: 2), isNull);
    expect(LinUCB.fromJson(m.toJson(), soTay: 3, soChieu: 3), isNull);
  });

  test('tay chưa thử được cộng điểm thăm dò nên vẫn tới lượt', () {
    final m = LinUCB(soTay: 2, soChieu: 1, ngau: Random(1));
    // Tay 0 ăn một phần thưởng nhỏ; tay 1 chưa có gì nhưng khoảng tin cậy
    // còn rộng nên điểm vẫn phải nhỉnh hơn.
    m.hoc([1], {0: 0.0});
    expect(m.diem(1, [1]), greaterThan(m.diem(0, [1])));
    // Ăn đủ nhiều lần thì mới vượt được phần thăm dò.
    for (var i = 0; i < 20; i++) {
      m.hoc([1], {0: 1});
    }
    expect(m.chon([1]), 0);
  });

  test('kín cả ngày thì nói thẳng là hết chỗ, không giả vờ còn', () {
    expect(GoiYGio.conCho(const []), isTrue);
    expect(GoiYGio.conCho([(0, 24 * 60)]), isFalse);
    // Tập rỗng không được hiểu thành "không ràng buộc": gộp hai thứ đó thì
    // lúc kín lịch bộ gợi ý lại chỉ thẳng vào giữa giờ học.
    final m = LinUCB(soTay: 3, soChieu: 1, ngau: Random(1));
    m.hoc([1], {2: 1});
    expect(m.chon([1]), 2);
    expect(m.chon([1], choPhep: {0, 1}), isNot(2));
  });

  test('khung đụng giờ bận thì loại khỏi danh sách gợi ý', () {
    // Bận 7h30–11h10 (tiết 1-4) thì khung 6–8h và 8–10h, 10–12h đều dính.
    expect(khungRanh([(7 * 60 + 30, 11 * 60 + 10)]), {3, 4, 5, 6, 7});
    expect(khungRanh(const []), {0, 1, 2, 3, 4, 5, 6, 7});
  });

  test('giờ quen thuộc mà hôm đó bận thì gợi ý khung khác', () async {
    final x = dacTrungGoiY(
      cuoiTuan: false,
      sang: false,
      chieu: true,
      toi: false,
    );
    for (var i = 0; i < 10; i++) {
      await GoiYGio.ghiNhan(x: x, goiYPhut: 14 * 60, chonPhut: 14 * 60);
    }
    expect(await GoiYGio.goiY(x), 14 * 60);
    // 13h–17h kín thì phải đề xuất giờ khác, chứ không bám thói quen.
    final khac = await GoiYGio.goiY(x, ban: [(13 * 60, 17 * 60)]);
    expect(khac, isNot(14 * 60));
    expect(khungRanh([(13 * 60, 17 * 60)]), contains(khungCuaGio(khac)));
  });

  test('thói quen cũ bị quên dần khi người dùng đổi giờ', () async {
    // Cả tháng đặt lịch lúc 8h...
    for (var i = 0; i < 20; i++) {
      await GoiYGio.ghiNhan(x: ranhCaNgay, goiYPhut: 8 * 60, chonPhut: 8 * 60);
    }
    expect(await GoiYGio.goiY(ranhCaNgay), 8 * 60);
    // ...rồi đổi sang 18h. LinUCB thường cộng dồn mãi nên 20 mẫu cũ còn đè
    // được chục mẫu mới; bản chiết khấu phải chuyển theo trong vòng đó.
    for (var i = 0; i < 12; i++) {
      final goi = await GoiYGio.goiY(ranhCaNgay);
      await GoiYGio.ghiNhan(
        x: ranhCaNgay,
        goiYPhut: goi,
        chonPhut: 18 * 60 + 30,
      );
    }
    expect(await GoiYGio.goiY(ranhCaNgay), 18 * 60);
  });

  test('bản lưu kiểu cũ (A nghịch đảo) vẫn đọc được, không mất cái đã học', () {
    final cu = LinUCB(soTay: 2, soChieu: 1, gamma: 1);
    for (var i = 0; i < 5; i++) {
      cu.hoc([1], {1: 1});
    }
    // Giả lập sổ của bản trước: chỉ có 'ainv' và 'b'.
    final sotay = {
      'chieu': 1,
      'alpha': LinUCB.alphaMacDinh,
      'ainv': [
        [1.0],
        [1 / 6],
      ],
      'b': cu.toJson()['b'],
    };
    final m = LinUCB.fromJson(sotay, soTay: 2, soChieu: 1, ngau: Random(1));
    expect(m, isA<LinUCB>());
    expect(m!.diem(1, [1]), closeTo(cu.diem(1, [1]), 1e-9));
  });

  test('đệm đi đường che luôn khung sát giờ tan tiết', () {
    // Tiết chiều 12h–13h50: khung 10h và 14h không chồng giờ, nhưng dính 15
    // phút đi đường nên cũng không đặt được.
    expect(khungRanh([(12 * 60, 13 * 60 + 50)]), {0, 1, 5, 6, 7});
    expect(khungRanh([(12 * 60, 13 * 60 + 50)], dem: 0), {0, 1, 2, 4, 5, 6, 7});
  });

  test('độ gấp của hạn suy giảm theo hàm mũ', () {
    expect(gapHan(null), 0); // không có hạn nào treo
    expect(gapHan(Duration.zero), 1);
    expect(gapHan(const Duration(hours: -3)), 1); // quá hạn vẫn là gấp nhất
    expect(gapHan(goiYNuaDoiHan), closeTo(0.5, 1e-9));
    expect(gapHan(goiYNuaDoiHan * 2), closeTo(0.25, 1e-9));
    // Xa thì chênh nhau không đáng kể, gần thì chênh hẳn — đó là lý do dùng
    // hàm mũ chứ không chia tuyến tính.
    final xa =
        gapHan(const Duration(days: 10)) - gapHan(const Duration(days: 12));
    final gan =
        gapHan(const Duration(hours: 2)) - gapHan(const Duration(hours: 12));
    expect(gan, greaterThan(xa * 100));
  });

  test('mức tải ngày bão hoà ở 1, ngày trống là 0', () {
    expect(taiNgay(0), 0);
    expect(taiNgay(goiYPhutKietSuc ~/ 2), closeTo(0.5, 1e-9));
    expect(taiNgay(goiYPhutKietSuc * 3), 1);
  });

  test(
    'lúc chưa có dữ liệu thì theo ưu tiên dựng tay, không bốc thăm',
    () async {
      // Mô hình trống: tám tay điểm bằng nhau, bốc ngẫu nhiên thì gợi ý mỗi lần
      // một giờ khác nhau. Khởi động bằng giờ sinh viên hay làm việc riêng.
      expect(await GoiYGio.goiY(ranhCaNgay), 18 * 60);
      // Ràng buộc cứng vẫn thắng ưu tiên.
      expect(
        await GoiYGio.goiY(ranhCaNgay, ban: [(17 * 60, 22 * 60)]),
        14 * 60,
      );
    },
  );

  test('hạn gấp thì khởi động bằng khung rảnh sớm nhất', () async {
    final gap = dacTrungGoiY(
      cuoiTuan: false,
      sang: false,
      chieu: false,
      toi: false,
      gap: gapHan(const Duration(hours: 3)),
    );
    expect(await GoiYGio.goiY(gap, ban: [(0, 9 * 60)]), 10 * 60);
    // Hạn còn xa thì không có gì phải giành giờ sớm.
    final xa = dacTrungGoiY(
      cuoiTuan: false,
      sang: false,
      chieu: false,
      toi: false,
      gap: gapHan(const Duration(days: 5)),
    );
    expect(await GoiYGio.goiY(xa, ban: [(0, 9 * 60)]), 18 * 60);
  });

  test('dời một khung vẫn được tính công, dời xa thì không', () {
    expect(thuongLech(0), 1);
    expect(thuongLech(1), greaterThan(thuongLech(2)));
    expect(thuongLech(2), greaterThan(0));
    expect(thuongLech(6), lessThan(0.01));
  });

  test('bỏ dở hoài thì bộ gợi ý thôi đề xuất khung đó', () async {
    for (var i = 0; i < 12; i++) {
      await GoiYGio.ghiNhan(x: ranhCaNgay, goiYPhut: 8 * 60, chonPhut: 8 * 60);
    }
    expect(await GoiYGio.goiY(ranhCaNgay), 8 * 60);
    // Đặt 8h thì đặt, nhưng lần nào cũng xoá đi — giờ chốt chỉ là ý định.
    for (var i = 0; i < 25; i++) {
      await GoiYGio.phanHoi(x: ranhCaNgay, phut: 8 * 60, xong: false);
    }
    expect(await GoiYGio.goiY(ranhCaNgay), isNot(8 * 60));
  });
}
