import 'package:dlu_tkb/custom_lich.dart';
import 'package:dlu_tkb/graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isoWeek matches the portal week numbers', () {
    expect(isoWeek(DateTime(2026, 9, 21)), 39); // thứ 2 của tuần 39
    expect(isoWeek(DateTime(2026, 9, 27)), 39); // chủ nhật cùng tuần
    expect(isoWeek(DateTime(2026, 9, 28)), 40);
  });

  test('itemsByDay groups by day and drops other months', () {
    final items = [
      {
        'StartDate': '21/09/2026',
        'DayOfWeek': 1,
        'NumberOfPeriods': 4,
        'PeriodID': 11,
      },
      {
        'StartDate': '21/09/2026',
        'DayOfWeek': 1,
        'NumberOfPeriods': 4,
        'PeriodID': 1,
      },
      {
        'StartDate': '21/09/2026',
        'DayOfWeek': 3,
        'NumberOfPeriods': 4,
        'PeriodID': 7,
      },
      {
        'StartDate': '28/09/2026',
        'DayOfWeek': 4,
        'NumberOfPeriods': 4,
        'PeriodID': 1,
      }, // 1/10
    ];
    expect(
      itemsByDay(
        items,
        DateTime(2026, 9),
      ).map((d, l) => MapEntry(d, periods(l))),
      {21: 8, 23: 4},
    );
    // sắp theo tiết, sáng trước tối
    expect(itemsByDay(items, DateTime(2026, 9))[21]!.first['PeriodID'], 1);
    expect(buoi(1), 'Sáng');
    expect(buoi(7), 'Chiều');
    expect(buoi(11), 'Tối');
  });

  test('yearTermFor suy học kỳ từ tháng', () {
    expect(yearTermFor(DateTime(2026, 9)), ('2026-2027', 'HK01'));
    expect(yearTermFor(DateTime(2027, 1)), ('2026-2027', 'HK01'));
    expect(yearTermFor(DateTime(2027, 3)), ('2026-2027', 'HK02'));
    expect(yearTermFor(DateTime(2027, 7)), ('2026-2027', 'HK03'));
  });

  test('màu ô theo số buổi học trong ngày', () {
    expect(
      dayColor(const []),
      isNot(
        dayColor(const [
          {'PeriodID': 1},
        ]),
      ),
    );
    // hai tiết cùng buổi sáng vẫn là một buổi
    expect(
      dayColor(const [
        {'PeriodID': 1},
        {'PeriodID': 3},
      ]),
      dayColor(const [
        {'PeriodID': 5},
      ]),
    );
    expect(
      dayColor(const [
        {'PeriodID': 1},
        {'PeriodID': 7},
      ]),
      isNot(
        dayColor(const [
          {'PeriodID': 1},
        ]),
      ),
    );
    expect(
      dayColor(const [
        {'PeriodID': 1},
        {'PeriodID': 7},
        {'PeriodID': 12},
      ]),
      isNot(
        dayColor(const [
          {'PeriodID': 1},
          {'PeriodID': 7},
        ]),
      ),
    );
  });

  test('khung giờ theo bảng giờ giảng của trường', () {
    expect(khungGio(1, 1), ('7h30', '8h20'));
    expect(khungGio(1, 4), ('7h30', '11h10'));
    expect(khungGio(7, 10), ('13h00', '16h30'));
    expect(khungGio(11, 14), ('16h40', '20h10'));
    expect(khungGio(0, 3), isNull);
    expect(tietNo('Tiết: 3'), 3);
    expect(buoi(6), 'Sáng');
  });

  test('tiết sắp tới và đếm ngược', () {
    final items = [
      {'BeginTime': 'Tiết: 1', 'EndTime': 'Tiết: 2'}, // 7h30 - 9h10
      {'BeginTime': 'Tiết: 7', 'EndTime': 'Tiết: 8'}, // 13h00 - 14h40
    ];
    final s = DateTime(2026, 9, 21, 6, 45);
    expect(tietKe(items, s), items[0]);
    expect(demNguoc(items[0], s), 'Còn 45 phút nữa');
    // Đang trong tiết thì vẫn là buổi hiện tại, không nhảy sang buổi sau.
    final giua = DateTime(2026, 9, 21, 8, 30);
    expect(tietKe(items, giua), items[0]);
    expect(demNguoc(items[0], giua), 'Còn 40 phút nữa');
    final trua = DateTime(2026, 9, 21, 11, 0);
    expect(tietKe(items, trua), items[1]);
    expect(demNguoc(items[1], trua), 'Còn 2 giờ nữa');
    // Tan hết thì không còn gì để nhắc.
    expect(tietKe(items, DateTime(2026, 9, 21, 20, 0)), isNull);
  });

  test('buổi 4 tiết đi qua từng tiết một, có cả ra chơi', () {
    final buoi = {'BeginTime': 'Tiết: 1', 'EndTime': 'Tiết: 4'}; // 7h30-11h10
    LessonNow? luc(int h, int m) =>
        lessonNow(buoi, DateTime(2026, 9, 21, h, m));

    expect(luc(7, 0), (pha: LessonPhase.chuaVao, tiet: 1, conPhut: 30));
    expect(luc(7, 40), (pha: LessonPhase.dangHoc, tiet: 1, conPhut: 40));
    expect(luc(8, 30), (pha: LessonPhase.dangHoc, tiet: 2, conPhut: 40));
    // Tiết 2 tan 9h10, tiết 3 mới vào 9h30 — ở giữa là ra chơi.
    expect(luc(9, 15), (pha: LessonPhase.raChoi, tiet: 3, conPhut: 15));
    expect(luc(9, 40), (pha: LessonPhase.dangHoc, tiet: 3, conPhut: 40));
    expect(luc(10, 30), (pha: LessonPhase.dangHoc, tiet: 4, conPhut: 40));
    expect(luc(11, 10), (pha: LessonPhase.xong, tiet: null, conPhut: 0));

    expect(phaseTag(luc(8, 30)!).$1, 'Đang học tiết 2');
    expect(
      demNguoc(buoi, DateTime(2026, 9, 21, 9, 15)),
      'Vào tiết 3 sau 15 phút',
    );
    expect(demNguoc(buoi, DateTime(2026, 9, 21, 11, 10)), isNull);
  });

  test('buổi ngắn thì hết tiết là tan luôn, không chờ hết buổi', () {
    // Chỉ một tiết: 13h00 - 13h50.
    final motTiet = {'BeginTime': 'Tiết: 7', 'EndTime': 'Tiết: 7'};
    expect(lessonNow(motTiet, DateTime(2026, 9, 21, 13, 30)), (
      pha: LessonPhase.dangHoc,
      tiet: 7,
      conPhut: 20,
    ));
    expect(lessonNow(motTiet, DateTime(2026, 9, 21, 13, 50)), (
      pha: LessonPhase.xong,
      tiet: null,
      conPhut: 0,
    ));
    // Hai tiết liền nhau thì không có ra chơi ở giữa.
    final haiTiet = {'BeginTime': 'Tiết: 7', 'EndTime': 'Tiết: 8'};
    expect(lessonNow(haiTiet, DateTime(2026, 9, 21, 13, 50)), (
      pha: LessonPhase.dangHoc,
      tiet: 8,
      conPhut: 50,
    ));
    // Tiết lạ thì không bịa trạng thái.
    expect(
      lessonNow({'BeginTime': 'x', 'EndTime': 'y'}, DateTime(2026)),
      isNull,
    );
  });

  test('buổi tối cũng có giải lao 18h20 - 18h30', () {
    final toi = {'BeginTime': 'Tiết: 11', 'EndTime': 'Tiết: 14'};
    expect(lessonNow(toi, DateTime(2026, 9, 21, 18, 25)), (
      pha: LessonPhase.raChoi,
      tiet: 13,
      conPhut: 5,
    ));
    expect(khungGio(13, 13), ('18h30', '19h20'));
  });

  test('customLessonNow đi qua chưa vào / đang học / xong theo phút', () {
    const c = CustomLich(tieuDe: 'ATC', batDau: 420, ketThuc: 480); // 7h-8h
    expect(
      customLessonNow(c, DateTime(2026, 9, 21, 6, 50))?.pha,
      LessonPhase.chuaVao,
    );
    expect(
      customLessonNow(c, DateTime(2026, 9, 21, 7, 30))?.pha,
      LessonPhase.dangHoc,
    );
    expect(
      customLessonNow(c, DateTime(2026, 9, 21, 8, 30))?.pha,
      LessonPhase.xong,
    );
    // Không có giờ về thì cứ coi như đang diễn ra, không tự "xong".
    const moGio = CustomLich(tieuDe: 'ATC', batDau: 420);
    expect(
      customLessonNow(moGio, DateTime(2026, 9, 21, 20, 0))?.pha,
      LessonPhase.dangHoc,
    );
  });

  test('ganLichTrongNgay gộp lịch chính quy và tự đặt theo đúng giờ vào', () {
    final tiet1 = {'BeginTime': 'Tiết: 1', 'EndTime': 'Tiết: 2'}; // 7h30
    final tiet7 = {'BeginTime': 'Tiết: 7', 'EndTime': 'Tiết: 8'}; // 13h00
    const somAC = CustomLich(tieuDe: 'ABC', batDau: 420, ketThuc: 540); // 7h00
    const toiXYZ = CustomLich(tieuDe: 'XYZ', batDau: 1000, ketThuc: 1060);
    expect(ganLichTrongNgay([tiet1, tiet7], [somAC, toiXYZ]), [
      somAC,
      tiet1,
      tiet7,
      toiXYZ,
    ]);
  });

  test('ketiepRieng chọn mục sớm nhất chưa xong, bỏ mục đã xong', () {
    final now = DateTime(2026, 9, 21, 9, 0);
    const daXong = CustomLich(tieuDe: 'Xong', batDau: 420, ketThuc: 480);
    const dangToi = CustomLich(tieuDe: 'Chiều', batDau: 900, ketThuc: 960);
    const gioHon = CustomLich(tieuDe: 'Sáng muộn', batDau: 600, ketThuc: 660);
    expect(ketiepRieng([daXong, dangToi, gioHon], now)?.tieuDe, 'Sáng muộn');
    expect(ketiepRieng([daXong], now), isNull);
  });

  test('trungGioChinhQuy báo đúng lúc lịch tự đặt đụng giờ buổi học', () {
    final tiet1 = {'BeginTime': 'Tiết: 1', 'EndTime': 'Tiết: 2'}; // 7h30-9h10
    // Hoàn toàn trước buổi học, không đụng giờ.
    const somHon = CustomLich(tieuDe: 'ABC', batDau: 360, ketThuc: 420);
    expect(trungGioChinhQuy(somHon, [tiet1]), isFalse);
    // Chen giữa khoảng giờ buổi học.
    const giuaBuoi = CustomLich(tieuDe: 'XYZ', batDau: 480, ketThuc: 500);
    expect(trungGioChinhQuy(giuaBuoi, [tiet1]), isTrue);
    // Không có giờ về thì coi như chiếm hết phần ngày còn lại, vẫn phải đụng.
    const moGio = CustomLich(tieuDe: 'Mở', batDau: 400);
    expect(trungGioChinhQuy(moGio, [tiet1]), isTrue);
  });
}
