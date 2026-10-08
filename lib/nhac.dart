import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'custom_lich.dart';
import 'data.dart';
import 'db.dart';
import 'graph.dart';

/// Một lần nhắc: [luc] là lúc rung máy, [vao] là giờ thật sự vào lớp. [tiet]
/// null là mục lịch tự đặt — nó không có tiết.
typedef MocNhac = ({
  DateTime luc,
  DateTime vao,
  String mon,
  String phong,
  int? tiet,
});

/// Các mốc cần nhắc, lấy từ lịch đã nạp sẵn. Bỏ mốc đã qua so với [now], sắp
/// theo thời gian rồi cắt còn [toiDa] — Android có trần số alarm chờ, mà nhắc
/// xa cả tháng thì tới lúc đó lịch cũng đã đổi và được đặt lại rồi.
List<MocNhac> mocNhac(
  Map<DateTime, List<dynamic>> ngay,
  DateTime now, {
  Duration truoc = Nhac.truoc,
  int toiDa = 30,
  Map<DateTime, List<CustomLich>> rieng = const {},
}) {
  final out = <MocNhac>[];
  for (final e in ngay.entries) {
    for (final i in e.value) {
      final tiet = tietNo(i['BeginTime']);
      final phut = batDauPhut(tiet);
      if (phut == null) continue;
      final vao = e.key.add(Duration(minutes: phut));
      final luc = vao.subtract(truoc);
      if (!luc.isAfter(now)) continue;
      out.add((
        luc: luc,
        vao: vao,
        mon: subjectName(i['CurriculumName']),
        phong: clean(i['RoomID']),
        tiet: tiet,
      ));
    }
  }
  for (final e in rieng.entries) {
    for (final c in e.value) {
      final vao = e.key.add(Duration(minutes: c.batDau));
      final luc = vao.subtract(truoc + demDuong(c, ngay[e.key] ?? const []));
      if (!luc.isAfter(now)) continue;
      out.add((
        luc: luc,
        vao: vao,
        mon: c.tieuDe,
        phong: c.viTri ?? '',
        tiet: null,
      ));
    }
  }
  out.sort((a, b) => a.luc.compareTo(b.luc));
  return out.take(toiDa).toList();
}

/// Thời gian đi đường cộng thêm vào lần nhắc. Chỉ cộng khi mục tự đặt có địa
/// điểm khác phòng của tiết ngay trước nó: tan tiết ở giảng đường rồi phải
/// chạy qua chỗ khác thì nhắc đúng giờ là trễ.
///
/// Không hỏi bản đồ, không đo quãng đường — trường nằm gọn một khuôn viên,
/// một con số cố định là đủ dùng.
// ponytail: một hằng số cho mọi chặng; đo thật khi nào app có toạ độ phòng.
const demDuongPhut = 15;

Duration demDuong(CustomLich c, List<dynamic> buoiTrongNgay) {
  final noi = c.viTri?.trim() ?? '';
  if (noi.isEmpty) return Duration.zero;
  String? phongTruoc;
  var ganNhat = -1;
  for (final i in buoiTrongNgay) {
    final cuoi = batDauPhut(tietNo(i['EndTime']));
    if (cuoi == null) continue;
    final tan = cuoi + tietPhut;
    if (tan <= c.batDau && tan > ganNhat) {
      ganNhat = tan;
      phongTruoc = clean(i['RoomID']);
    }
  }
  if (phongTruoc == null || phongTruoc.isEmpty) return Duration.zero;
  return phongTruoc.toLowerCase() == noi.toLowerCase()
      ? Duration.zero
      : const Duration(minutes: demDuongPhut);
}

/// Nhắc trước giờ vào lớp bằng thông báo hệ thống. Không đụng tới portal:
/// chỉ đọc lịch đã nạp sẵn rồi hẹn máy rung đúng giờ, nên tắt mạng vẫn kêu.
class Nhac {
  static const truoc = Duration(minutes: 15);
  static const _khoa = 'nhac_truoc_gio';
  // Đổi id kênh vì Android khoá cấu hình kênh ngay lần tạo đầu: kênh cũ đã
  // đăng ký có tiếng thì sửa code cũng vô ích, phải là kênh mới.
  static const _kenh = 'sap_vao_lop_im';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _sanSang = false;

  /// Có bật nhắc không — mặc định tắt. Thông báo là thứ tự nó chen vào máy
  /// người ta nên phải do họ bật, đừng bật sẵn hộ.
  static Future<bool> bat() async =>
      (await Db.i.dong(nhomCaiDat, _khoa))?.bat ?? false;

  static Future<void> datBat(bool v) async {
    await Db.i.ghi(nhomCaiDat, _khoa, bat: v);
    if (!v) await _plugin.cancelAll();
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Máy có cho hẹn đúng phút không. Android 14 trở lên mặc định là không,
  /// và hẹn xấp xỉ thì hệ thống được phép dồn trễ cả tiếng — nhắc trước 15
  /// phút mà tới nơi lớp đã vào rồi thì coi như hỏng.
  static Future<bool> chinhXacDuoc() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Mở thẳng trang cấp quyền báo thức chính xác. Chỉ gọi khi người dùng tự
  /// bấm — không được lôi họ ra màn cài đặt giữa lúc app đang mở lên.
  static Future<void> xinChinhXac() async {
    try {
      await _moDau();
      await _android?.requestExactAlarmsPermission();
    } catch (_) {
      // Máy không có trang đó thì thôi.
    }
  }

  static Future<void> _moDau() async {
    if (_sanSang) return;
    tzdata.initializeTimeZones();
    // App của một trường ở Đà Lạt nên múi giờ cố định; khỏi thêm một
    // package chỉ để hỏi máy đang đứng ở đâu.
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _android?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _sanSang = true;
  }

  /// Đặt lại toàn bộ lịch nhắc theo [ngay]. Xoá sạch rồi đặt từ đầu, khỏi
  /// phải dò xem cái nào đặt rồi — lịch trường đổi thì lượt sau tự đúng.
  ///
  /// Nuốt mọi lỗi: máy không cho thông báo, chưa cấp quyền, hay đang chạy
  /// trong test không có platform channel thì cũng không được phép làm hỏng
  /// lượt nạp dữ liệu đang gọi nó.
  static Future<void> datLai(Map<DateTime, List<dynamic>> ngay) async {
    try {
      if (!await bat()) return;
      await _moDau();
      await _plugin.cancelAll();
      var id = 0;
      final now = DateTime.now();
      for (final m in mocNhac(ngay, now, rieng: await _riengQuanh(now))) {
        await _dat(id++, m);
      }
    } catch (_) {
      // Không hẹn được thì thôi, app vẫn chạy bình thường.
    }
  }

  /// Lịch tự đặt của hai tuần tới. Mục lặp trải ra thành từng buổi nên cứ
  /// hỏi theo ngày; xa hơn hai tuần thì tới lúc đó app đã đặt lại rồi.
  static Future<Map<DateTime, List<CustomLich>>> _riengQuanh(
    DateTime now,
  ) async {
    final hom = DateTime(now.year, now.month, now.day);
    final out = <DateTime, List<CustomLich>>{};
    for (var i = 0; i < 14; i++) {
      final d = hom.add(Duration(days: i));
      final ds = await CustomLichStore.forDay(d);
      if (ds.isNotEmpty) out[d] = ds;
    }
    return out;
  }

  static Future<void> _dat(int id, MocNhac m) async {
    final tiet = m.tiet;
    final phong = m.phong.isEmpty
        ? ''
        : ' — ${tiet == null ? '' : 'phòng '}${m.phong}';
    final gio = '${m.vao.hour}h${m.vao.minute.toString().padLeft(2, '0')}';
    Future<void> hen(AndroidScheduleMode che) => _plugin.zonedSchedule(
      id: id,
      title: tiet == null ? 'Sắp tới giờ: ${m.mon}' : 'Sắp vào lớp: ${m.mon}',
      body: tiet == null ? 'Lúc $gio$phong' : 'Tiết $tiet lúc $gio$phong',
      scheduledDate: tz.TZDateTime.from(m.luc, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _kenh,
          'Sắp vào lớp',
          channelDescription: 'Nhắc trước 15 phút khi tới giờ lên lớp',
          importance: Importance.high,
          priority: Priority.high,
          // Im tiếng, chỉ rung: nhắc trong giờ học hay giờ ngủ đều không nên
          // kêu lên.
          playSound: false,
        ),
        iOS: DarwinNotificationDetails(presentSound: false),
      ),
      androidScheduleMode: che,
    );

    try {
      await hen(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      // Android 12+ chưa cấp quyền hẹn chính xác: hẹn xấp xỉ vẫn hơn không
      // nhắc, máy chỉ được phép dồn trễ vài phút.
      await hen(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }
}
