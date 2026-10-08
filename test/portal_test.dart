import 'dart:convert';

import 'package:dlu_tkb/portal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client stub(int status, Object body) => MockClient(
  (_) async => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  ),
);

void main() {
  setUp(dungDbTam);

  test('reads the session out of a successful login', () async {
    final s = await Portal(
      client: stub(200, {
        'Id': '2312577',
        'FullName': 'Trần Nguyễn Tuấn Anh',
        'Token': 'jwt-here',
        'Role': 'SV',
        'IsLogin': true,
        'Message': '',
        'Expire': '2026-09-27T02:28:06.94197+07:00',
      }),
    ).login('2312577', 'x');

    expect(s.id, '2312577');
    expect(s.fullName, 'Trần Nguyễn Tuấn Anh'); // utf8, not mojibake
    expect(s.token, 'jwt-here');
    // So với một mốc tuyệt đối chứ không phải nửa đêm giờ máy: CI chạy
    // giờ UTC thì 02:28 +07 rơi về ngày hôm trước, phép so lật ngược.
    expect(s.expire.toUtc(), DateTime.utc(2026, 9, 26, 19, 28, 6, 941, 970));
  });

  test('surfaces the portal message when login is refused', () async {
    final call = Portal(
      client: stub(200, {'IsLogin': false, 'Message': 'Mật khẩu không đúng'}),
    ).login('2312577', 'sai');

    expect(
      call,
      throwsA(
        isA<PortalError>().having(
          (e) => e.message,
          'message',
          'Mật khẩu không đúng',
        ),
      ),
    );
  });

  test('falls back to a readable message when the portal says nothing', () {
    expect(
      Portal(client: stub(200, {'IsLogin': false})).login('a', 'b'),
      throwsA(
        isA<PortalError>().having(
          (e) => e.message,
          'message',
          contains('Sai tài khoản'),
        ),
      ),
    );
  });

  test('sai mật khẩu (400) thì nói là sai mật khẩu, không đọc mã lỗi', () {
    expect(
      Portal(
        client: stub(400, {'Message': 'Tài khoản hoặc mật khẩu không đúng'}),
      ).login('2312577', 'sai'),
      throwsA(
        isA<PortalError>()
            .having(
              (e) => e.message,
              'message',
              'Tài khoản hoặc mật khẩu không đúng',
            )
            // Loại này mới được xoá mật khẩu đã lưu và đá về màn đăng nhập.
            .having((e) => e.saiMatKhau, 'saiMatKhau', isTrue),
      ),
    );
  });

  test('400 trơn thì vẫn nói tiếng Việt, mà không xoá mật khẩu đã lưu', () {
    expect(
      Portal(
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode('Bad Request'), 400),
        ),
      ).login('a', 'b'),
      throwsA(
        isA<PortalError>()
            .having((e) => e.message, 'message', contains('Sai tài khoản'))
            // Proxy chen vào hay mạng bắt đăng nhập wifi cũng ra 400 trơn:
            // mật khẩu trong Keychain phải còn nguyên.
            .having((e) => e.saiMatKhau, 'saiMatKhau', isFalse),
      ),
    );
  });

  test('lỗi phía server thì vẫn là lỗi server, không vu cho mật khẩu', () {
    expect(
      Portal(client: stub(500, {})).login('a', 'b'),
      throwsA(
        isA<PortalError>().having((e) => e.saiMatKhau, 'saiMatKhau', isFalse),
      ),
    );
  });

  test('reports HTTP failures instead of crashing', () {
    expect(
      Portal(client: stub(500, {})).login('a', 'b'),
      throwsA(
        isA<PortalError>().having((e) => e.message, 'message', contains('500')),
      ),
    );
  });

  test('studentInfo sends the token and unwraps sinhVien', () async {
    String? auth;
    final info = await Portal(
      client: MockClient((req) async {
        auth = req.headers['authorization'];
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'sinhVien': {
                'MaSinhVien': '2312577',
                'HoTen': 'Trần Nguyễn Tuấn Anh',
              },
              'IsUpdate': {'Result': 1},
            }),
          ),
          200,
        );
      }),
    ).studentInfo('tok');

    expect(auth, 'Bearer tok');
    expect(info['HoTen'], 'Trần Nguyễn Tuấn Anh');
  });
}
