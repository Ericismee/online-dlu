import 'dart:convert';
import 'dart:io';

import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUpAll(() async {
    Hive.init('${Directory.systemTemp.path}/dlu_test_cache');
    await Cache.open();
  });

  tearDown(() => Cache.clear());

  test('lần hai lấy từ cache, xoá cache thì gọi lại portal', () async {
    var calls = 0;
    final portal = Portal(
      client: MockClient((_) async {
        calls++;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {'LastScore': 90},
            ]),
          ),
          200,
        );
      }),
    );
    await portal.behaviorScores('t');
    await portal.behaviorScores('t');
    expect(calls, 1);

    await Cache.clear();
    await portal.behaviorScores('t');
    expect(calls, 2);
  });

  test('stale theo ttl', () {
    expect(Cache.stale(DateTime.now()), isFalse);
    expect(Cache.stale(DateTime.now().subtract(Cache.ttl * 2)), isTrue);
  });

  test('mốc dữ liệu chỉ nhích khi thật sự lấy được', () async {
    var hong = false;
    final portal = Portal(
      client: MockClient((_) async {
        if (hong) return http.Response.bytes(utf8.encode('{}'), 500);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {'LastScore': 90},
            ]),
          ),
          200,
        );
      }),
    );
    expect(Cache.syncedAt, isNull);
    await portal.behaviorScores('t');
    final lanDau = Cache.syncedAt;
    expect(lanDau, isNotNull);

    // Lấy lại lúc mạng hỏng: màn giữ số cũ nên mốc phải đứng yên.
    hong = true;
    Cache.bypass = true;
    await expectLater(portal.behaviorScores('t'), throwsA(isA<PortalError>()));
    Cache.bypass = false;
    expect(Cache.syncedAt, lanDau);

    // Đọc lại từ cache thì mốc là lúc cache ghi, không phải bây giờ.
    await portal.behaviorScores('t');
    expect(Cache.syncedAt, lanDau);
  });
}
