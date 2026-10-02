import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() async {
    dungDbTam();
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

    // Lấy lại lúc mạng hỏng: đưa lại số cũ, và mốc phải đứng yên.
    hong = true;
    Cache.bypass = true;
    expect((await portal.behaviorScores('t')).first['LastScore'], 90);
    Cache.bypass = false;
    expect(Cache.syncedAt, lanDau);

    // Đọc lại từ cache thì mốc là lúc cache ghi, không phải bây giờ.
    await portal.behaviorScores('t');
    expect(Cache.syncedAt, lanDau);
  });

  test('kéo làm mới ở màn này thì màn mở sau cũng lấy số mới', () async {
    var calls = 0;
    var hong = false;
    final portal = Portal(
      client: MockClient((_) async {
        calls++;
        if (hong) throw const SocketException('mất mạng');
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

    // Kéo làm mới trong khi màn 'điểm rèn luyện' chưa mở: cache của nó
    // cũng phải hết giá trị.
    await Cache.refreshAll();
    await portal.behaviorScores('t');
    expect(calls, 2);

    // Nhưng mất mạng thì vẫn đưa số cũ ra, không quăng lỗi lên màn.
    await Cache.refreshAll();
    hong = true;
    final cu = await portal.behaviorScores('t');
    expect(calls, 3);
    expect(cu.first['LastScore'], 90);
  });

  test('đang làm mới thì syncedAt vẫn đứng yên, không rớt về rỗng', () async {
    final portal = Portal(
      client: MockClient((_) async {
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
    final truoc = Cache.syncedAt;
    expect(truoc, isNotNull);

    // Refresher cố tình chờ lâu để lộ khoảng hở giữa lúc bắt đầu làm mới
    // và lúc portal trả về — đúng lúc này mà màn nào đó đọc syncedAt thì
    // không được thấy rỗng hay mốc lạ.
    final cho = Completer<void>();
    Cache.refreshers.add(() async {
      await cho.future;
      await portal.behaviorScores('t');
    });
    final dangChay = Cache.refreshAll();
    expect(Cache.syncedAt, truoc);
    cho.complete();
    await dangChay;
    Cache.refreshers.clear();
  });

  test('portal lỗi giữa lượt làm mới thì giữ số cũ, không xoá màn', () async {
    var hong = false;
    final portal = Portal(
      client: MockClient((_) async {
        if (hong) return http.Response.bytes(utf8.encode('{}'), 400);
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

    // Mở app là làm mới hết; portal trả 400 thì vẫn phải thấy số cũ chứ
    // không phải màn báo lỗi đỏ.
    hong = true;
    Cache.bypass = true;
    Cache.refreshedAt = DateTime.now();
    final cu = await portal.behaviorScores('t');
    Cache.bypass = false;
    expect(cu.first['LastScore'], 90);

    // Chưa có gì trong máy thì đành báo lỗi thật.
    await Cache.clear();
    await expectLater(portal.behaviorScores('t'), throwsA(isA<PortalError>()));
  });
}
