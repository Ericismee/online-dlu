import 'dart:convert';

import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:dlu_tkb/prefetch.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() async {
    dungDbTam();
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

    // Đã nạp rồi thì các màn mở sau đọc trong máy, không gọi portal nữa.
    final xong = hit.length;
    await portal.exams('t');
    await portal.studentInfo('t');
    expect(hit.length, xong);

    // Nhưng mở app lần nữa là lại thử lấy số mới, dù cache còn hạn.
    await Prefetch.run(session, portal: portal);
    expect(hit.length, xong * 2);
  });

  test('lấy về kịp thì mốc dữ liệu nhích lên, hỏng thì đứng yên', () async {
    var hong = false;
    final portal = Portal(
      client: MockClient((req) async {
        if (hong) return http.Response.bytes(utf8.encode('{}'), 500);
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
    await portal.exams('t');
    final cu = Cache.served['/api/student/showexambytime'];
    expect(cu, isNotNull);

    // Nạp sẵn lấy được số mới: mốc phải là lúc này, không phải lúc ghi cache.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await Prefetch.run(
      Session(id: '1', fullName: 'A', token: 't', expire: DateTime(2030)),
      portal: portal,
    );
    final moi = Cache.served['/api/student/showexambytime'];
    expect(moi!.isAfter(cu!), isTrue);

    // Không lấy được thì thôi, màn vẫn số cũ và mốc đứng yên.
    hong = true;
    await Prefetch.run(
      Session(id: '1', fullName: 'A', token: 't', expire: DateTime(2030)),
      portal: portal,
    );
    expect(Cache.served['/api/student/showexambytime'], moi);
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
