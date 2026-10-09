import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:dlu_tkb/info.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(dungDbTam);

  testWidgets('thẻ sinh viên đổi được giữa mã vạch và mã QR', (t) async {
    final portal = Portal(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'sinhVien': {
                'HoTen': 'Nguyễn Văn A',
                'MaSinhVien': '2012345',
                'LopSinhVien': 'CTK46',
              },
            }),
          ),
          200,
        ),
      ),
    );
    t.view.physicalSize = const Size(1200, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: InfoScreen(
          session: Session(
            id: '2012345',
            fullName: 'Nguyễn Văn A',
            token: 't',
            expire: DateTime(2030),
          ),
          onLogout: () {},
          onGo: (_) {},
          portal: portal,
        ),
      ),
    );
    await t.pump();
    await t.pump();

    // Mở ra là mã vạch, nội dung đúng MSSV.
    var bar = t.widget<BarcodeWidget>(find.byType(BarcodeWidget));
    // Widget giữ data dạng bytes.
    expect(utf8.decode(bar.data), '2012345');
    expect(bar.barcode.name, Barcode.code128().name);

    await t.tap(find.text('Mã QR'));
    await t.pump();
    bar = t.widget<BarcodeWidget>(find.byType(BarcodeWidget));
    expect(bar.barcode.name, Barcode.qrCode().name);
    expect(utf8.decode(bar.data), '2012345');
  });
}
