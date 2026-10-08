import 'dart:convert';

import 'package:dlu_tkb/nhat_ky.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'db_tam.dart';

void main() {
  setUp(() async {
    await dungDbTam();
    NhatKy.xoa();
    NhatKy.bat = true;
  });
  tearDown(() {
    NhatKy.bat = false;
    NhatKy.xoa();
  });

  test('tắt là không ghi gì', () {
    NhatKy.bat = false;
    NhatKy.ghi('app', 'x');
    expect(NhatKy.dong.value, isEmpty);
  });

  test('chỉ giữ giới hạn dòng gần nhất, mới nhất nằm đầu', () {
    for (var i = 0; i <= NhatKy.gioiHan; i++) {
      NhatKy.ghi('app', 'dòng $i');
    }
    expect(NhatKy.dong.value.length, NhatKy.gioiHan);
    expect(NhatKy.dong.value.first.viec, 'dòng ${NhatKy.gioiHan}');
  });

  test('địa chỉ cắt sạch query, token không vào sổ', () {
    expect(
      NhatKy.diaChi(
        Uri.parse(
          'https://lms.dlu.edu.vn/webservice/rest/server.php'
          '?wstoken=bimat&wsfunction=core_webservice_get_site_info',
        ),
      ),
      'lms.dlu.edu.vn/webservice/rest/server.php',
    );
  });

  test('lượt đăng nhập vào sổ mà mật khẩu thì không', () async {
    await Portal(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'Id': '2312577',
              'FullName': 'A',
              'Token': 'jwt',
              'Role': 'SV',
              'IsLogin': true,
              'Message': '',
              'Expire': '2026-09-27T02:28:06.94197+07:00',
            }),
          ),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    ).login('2312577', 'matkhau-that');

    final so = NhatKy.dong.value.map((d) => d.viec).join('\n');
    expect(so, contains('POST'));
    expect(so, isNot(contains('matkhau-that')));
    expect(so, isNot(contains('2312577')));
  });
}
