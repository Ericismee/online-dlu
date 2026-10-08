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
}
