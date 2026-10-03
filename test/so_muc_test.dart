import 'dart:convert';

import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/db.dart';
import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:dlu_tkb/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_tam.dart';

/// Moodle luôn từ chối: lấy được logintoken rồi đẩy ngược về form trống.
MockClient get _moodleTuChoi => MockClient((req) async {
  if (req.method == 'GET') {
    return http.Response(
      '<input type="hidden" name="logintoken" value="tok1">',
      200,
      headers: {'set-cookie': 'MoodleSession=vodanh; path=/'},
    );
  }
  return http.Response(
    '',
    303,
    headers: {'location': 'https://lms.dlu.edu.vn/login/index.php'},
  );
});

void main() {
  setUp(dungDbTam);

  group('sổ mục của portal', () {
    const path = '/api/student/showexambytime';
    final a = {'id': 1};
    final b = {'id': 2};

    test(
      'mục mới thì thêm, mục portal thôi trả về thì ẩn chứ không xoá',
      () async {
        await DsKho.nhap(path, [a, b]);
        expect(await DsKho.doc(path), hasLength(2));

        // Mẻ sau portal rụng mất `a`.
        expect(await DsKho.nhap(path, [b]), [b]);
        expect(await DsKho.doc(path), [b]);
        // Dòng của `a` vẫn còn nguyên trong sổ, chỉ tắt cờ bật.
        final dong = await Db.i.dong(DsKho.nhomCua(path), jsonEncode(a));
        expect(dong, isNotNull);
        expect(dong!.bat, isFalse);
      },
    );

    test('mẻ rỗng thì giữ nguyên mục đang có', () async {
      await DsKho.nhap(path, [a, b]);
      // Portal trả rỗng gần như luôn là nó lỗi, không phải sinh viên hết môn.
      expect(await DsKho.nhap(path, const []), hasLength(2));
      expect(await DsKho.doc(path), hasLength(2));
    });
  });

  group('chỉ sai mật khẩu mới được đá về Login', () {
    test('portal từ chối tài khoản: saiMatKhau', () {
      expect(
        () => Session.fromJson({'IsLogin': false}),
        throwsA(
          isA<PortalError>().having((e) => e.saiMatKhau, 'saiMatKhau', isTrue),
        ),
      );
    });

    test('portal lỗi HTTP hay mất mạng: mật khẩu vẫn đúng', () async {
      for (final ma in [403, 500]) {
        await expectLater(
          Portal(client: MockClient((_) async => http.Response('', ma)))
              .login('a', 'b'),
          throwsA(
            isA<PortalError>().having(
              (e) => e.saiMatKhau,
              'saiMatKhau',
              isFalse,
            ),
          ),
        );
      }
    });
  });

  test('mật khẩu LMS sai thì tắt LMS và báo vào chuông', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'lms_username': '2312577',
      'lms_password': 'sai',
    });
    await Settings.datLmsBat(true);
    Lms.boPhien();

    await expectLater(
      Lms.phien(lms: Lms(client: _moodleTuChoi)),
      throwsA(isA<PortalError>()),
    );

    expect(await Settings.lmsBat(), isFalse);
    final tin = (await LmsKho.doc()).singleWhere(
      (n) => n.id == LmsKho.khoaSaiMatKhau,
    );
    expect(tin.unread, isTrue);
    expect(tin.body, contains('2312577'));
    // Mật khẩu đã lưu giữ nguyên: chỉ phải sửa, khỏi gõ lại từ đầu.
    expect((await LmsVault.read())?.$1, '2312577');

    // Đăng nhập lại được thì tin cảnh báo đi khỏi chuông.
    await LmsKho.thoiBaoSaiMatKhau();
    expect(await LmsKho.doc(), isEmpty);
  });
}
