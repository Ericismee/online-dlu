import 'package:dlu_tkb/cache.dart';
import 'package:dlu_tkb/clock.dart';
import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/main.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

void main() {
  setUp(() async {
    await dungDbTam();
    FlutterSecureStorage.setMockInitialValues({
      'username': '2312577',
      'password': 'mk',
    });
    await Cache.write(
      'session',
      Session(
        id: '2312577',
        fullName: 'Nguyễn Văn A',
        token: 't',
        expire: DateTime(2030),
      ).toMap(),
    );
    // Nhịp dài hơn cả bài test: cái gì chạy được cũng chỉ do lượt quay lại.
    LmsNhip.khoang = () => const Duration(minutes: 5);
  });
  tearDown(() => LmsNhip.khoang = () => const Duration(seconds: 90));

  testWidgets(
    'quay lại từ app khác là lấy ngay, lướt Trung tâm điều khiển thì không',
    (t) async {
      var lan = 0;
      Future<void> dem() async => lan++;
      LmsNhip.them(dem);
      // Test xong mà còn Timer treo là binding báo lỗi.
      addTearDown(() => LmsNhip.bo(dem));

      await t.pumpWidget(const App());
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));

      // Chỉ `inactive` rồi `resumed` (kéo Trung tâm điều khiển): app chưa hề
      // xuống nền, nhịp vẫn chạy, không được gọi thêm lượt nào.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      expect(lan, 0);

      // Xuống nền thật rồi quay lại: nhịp đã tắt nên phải lấy ngay một lượt.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      expect(lan, 1);

      // Cho xuống nền lần nữa để tắt hết nhịp: binding soi Timer treo ngay
      // cuối thân test, trước cả tearDown.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      LmsNhip.bo(dem);
      Clock.instance.stop();
    },
  );
}
