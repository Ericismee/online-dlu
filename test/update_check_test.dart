import 'dart:convert';

import 'package:dlu_tkb/update_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Online DLU',
      packageName: 'com.dopaemon.dluonline',
      version: '1.0.1',
      buildNumber: '2',
      buildSignature: '',
    );
  });

  Future<String?> latest(String tag) => UpdateCheck.newerVersion(
    client: MockClient(
      (req) async => http.Response(jsonEncode({'tag_name': tag}), 200),
    ),
  );

  test('GitHub có bản mới hơn thì trả về tag', () async {
    expect(await latest('v1.0.2'), '1.0.2');
  });

  test('Cùng bản hoặc cũ hơn thì im lặng', () async {
    expect(await latest('v1.0.1'), isNull);
    expect(await latest('v1.0.0'), isNull);
  });

  test('GitHub lỗi thì im lặng, không văng', () async {
    final v = await UpdateCheck.newerVersion(
      client: MockClient((req) async => http.Response('', 500)),
    );
    expect(v, isNull);
  });
}
