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
}
