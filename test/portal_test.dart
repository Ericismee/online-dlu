import 'dart:convert';

import 'package:dlu_tkb/portal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client stub(int status, Object body) => MockClient(
      (_) async => http.Response.bytes(utf8.encode(jsonEncode(body)), status,
          headers: {'content-type': 'application/json'}),
    );

void main() {
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
    expect(s.expire.isAfter(DateTime(2026, 9, 27)), isTrue);
  });

  test('surfaces the portal message when login is refused', () async {
    final call = Portal(
      client: stub(200, {'IsLogin': false, 'Message': 'Mật khẩu không đúng'}),
    ).login('2312577', 'sai');

    expect(call, throwsA(isA<PortalError>()
        .having((e) => e.message, 'message', 'Mật khẩu không đúng')));
  });

  test('falls back to a readable message when the portal says nothing', () {
    expect(Portal(client: stub(200, {'IsLogin': false})).login('a', 'b'),
        throwsA(isA<PortalError>()
            .having((e) => e.message, 'message', contains('Sai tài khoản'))));
  });

  test('reports HTTP failures instead of crashing', () {
    expect(Portal(client: stub(500, {})).login('a', 'b'),
        throwsA(isA<PortalError>()
            .having((e) => e.message, 'message', contains('500'))));
  });

  test('studentInfo sends the token and unwraps sinhVien', () async {
    String? auth;
    final info = await Portal(client: MockClient((req) async {
      auth = req.headers['authorization'];
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'sinhVien': {'MaSinhVien': '2312577', 'HoTen': 'Trần Nguyễn Tuấn Anh'},
            'IsUpdate': {'Result': 1},
          })),
          200);
    })).studentInfo('tok');

    expect(auth, 'Bearer tok');
    expect(info['HoTen'], 'Trần Nguyễn Tuấn Anh');
  });
}
