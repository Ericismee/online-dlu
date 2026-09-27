import 'dart:convert';
import 'dart:io';

import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:dlu_tkb/prefetch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('dlu_test_prefetch').path);
    await Cache.open();
  });

  tearDown(() async {
    await Cache.clear();
    Prefetch.xongLuc = null;
  });

  test('mở app là nạp sẵn hết, mở màn sau không gọi portal nữa', () async {
    final hit = <String>[];
    final portal = Portal(
      client: MockClient((req) async {
        hit.add(req.url.path);
        final body = switch (req.url.path) {
          '/api/student/info' => {'sinhVien': {}},
          '/api/student/GetStudyProgram' => [
            {'StudyProgramID': 'CQ2021'},
          ],
          '/api/student/studyProgram' => {'tbStudyPrograms': []},
          '/api/student/DrawingSchedules_v2' => {'ResultDataSchedule': []},
          '/api/student/BehaviorByStudent' => {},
          _ => [],
        };
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );
    final session = Session(
      id: '1',
      fullName: 'A',
      token: 't',
      expire: DateTime(2030),
    );

    await Prefetch.run(session, portal: portal);
    expect(
      hit,
      containsAll([
        '/api/student/info',
        '/api/student/showexambytime',
        '/api/student/GetMessagesByReceiverID',
        '/api/student/behaviorscoretotal',
        '/api/student/BehaviorByStudent',
        '/api/student/XemKetQuaDangKyHP',
        '/api/student/marks',
        '/api/student/studyProgram',
        '/api/student/DrawingSchedules_v2',
      ]),
    );

    // Đã nạp rồi thì các màn mở sau đọc trong máy, và lượt nạp thứ hai
    // trong cùng phiên không đụng tới server trường nữa.
    final xong = hit.length;
    await portal.exams('t');
    await portal.studentInfo('t');
    await Prefetch.run(session, portal: portal);
    expect(hit.length, xong);
  });

  test('một mục lỗi thì các mục sau vẫn nạp', () async {
    final hit = <String>[];
    final portal = Portal(
      client: MockClient((req) async {
        hit.add(req.url.path);
        if (req.url.path == '/api/student/info') {
          return http.Response.bytes(utf8.encode('{}'), 500);
        }
        final body = switch (req.url.path) {
          '/api/student/GetStudyProgram' => [
            {'StudyProgramID': 'CQ2021'},
          ],
          '/api/student/studyProgram' => {'tbStudyPrograms': []},
          '/api/student/DrawingSchedules_v2' => {'ResultDataSchedule': []},
          '/api/student/BehaviorByStudent' => {},
          _ => [],
        };
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );
    await Prefetch.run(
      Session(id: '1', fullName: 'A', token: 't', expire: DateTime(2030)),
      portal: portal,
    );
    expect(hit, contains('/api/student/showexambytime'));
  });
}
