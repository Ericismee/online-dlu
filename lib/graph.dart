import 'package:flutter/material.dart';

import 'data.dart';
import 'paper.dart';
import 'portal.dart';

/// Tuần ISO của một ngày — portal đánh số tuần theo chuẩn này (21/09/2026 = 39).
int isoWeek(DateTime d) {
  final thu = d.add(Duration(days: 4 - d.weekday));
  return thu.difference(DateTime(thu.year, 1, 1)).inDays ~/ 7 + 1;
}

/// Lịch học gom theo ngày trong tháng. Key = ngày, giá trị đã sắp theo tiết.
Map<int, List<dynamic>> itemsByDay(Iterable<dynamic> items, DateTime month) {
  final out = <int, List<dynamic>>{};
  for (final i in items) {
    final p = (i['StartDate'] as String).split('/'); // dd/MM/yyyy của thứ 2
    final monday = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    final day = monday.add(Duration(days: toNum(i['DayOfWeek']).toInt() - 1));
    if (day.year != month.year || day.month != month.month) continue;
    out.putIfAbsent(day.day, () => []).add(i);
  }
  for (final l in out.values) {
    l.sort(
      (a, b) => toNum(a['PeriodID']).toInt() - toNum(b['PeriodID']).toInt(),
    );
  }
  return out;
}

int periods(Iterable<dynamic> items) =>
    items.fold(0, (a, i) => a + toNum(i['NumberOfPeriods']).toInt());

/// Tiết 1-6 sáng, 7-10 chiều, 11-14 tối (theo bảng giờ giảng của trường).
String buoi(int periodID) =>
    periodID <= 6 ? 'Sáng' : (periodID <= 10 ? 'Chiều' : 'Tối');

/// Phút bắt đầu của từng tiết theo bảng giờ giảng của trường, mỗi tiết 50 phút.
// ponytail: trường chỉ công bố tiết 1-4, 7-14; tiết 5-6 suy ra tiếp nối tiết 4.
const _batDau = <int, int>{
  1: 7 * 60 + 30,
  2: 8 * 60 + 20,
  3: 9 * 60 + 30,
  4: 10 * 60 + 20,
  5: 11 * 60 + 10,
  6: 12 * 60,
  7: 13 * 60,
  8: 13 * 60 + 50,
  9: 14 * 60 + 50,
  10: 15 * 60 + 40,
  11: 16 * 60 + 40,
  12: 17 * 60 + 30,
  13: 18 * 60 + 20,
  14: 19 * 60 + 10,
};

String _gio(int phut) =>
    '${phut ~/ 60}h${(phut % 60).toString().padLeft(2, '0')}';

/// Số tiết trong chuỗi portal trả về ('Tiết: 3' -> 3).
int tietNo(Object? v) =>
    int.tryParse(RegExp(r'\d+').firstMatch(clean(v))?.group(0) ?? '') ?? 0;

/// Giờ vào - giờ ra của một dải tiết. Tiết lạ thì trả null để khỏi bịa giờ.
(String, String)? khungGio(int tietDau, int tietCuoi) {
  final dau = _batDau[tietDau];
  final cuoi = _batDau[tietCuoi];
  if (dau == null || cuoi == null) return null;
  return (_gio(dau), _gio(cuoi + 50));
}

/// Màu ô lịch theo số buổi phải lên lớp trong ngày (sáng/chiều/tối).
Color dayColor(Iterable<dynamic> items) {
  final buoiTrongNgay = items
      .map((i) => buoi(toNum(i['PeriodID']).toInt()))
      .toSet();
  return switch (buoiTrongNgay.length) {
    0 => _nghi,
    1 => _motBuoi,
    2 => _haiBuoi,
    _ => _baBuoi,
  };
}

const _nghi = Color(0xFFF2E7CE); // nghỉ — không có tiết nào
const _motBuoi = Paper.mint; // xanh lá — học 1 buổi
const _haiBuoi = Paper.sky; // xanh dương — học 2 buổi
const _baBuoi = Paper.rose; // đỏ — học cả 3 buổi

/// Năm học / học kỳ của một tháng. HK01 tháng 8-1, HK02 tháng 2-6, HK03 tháng 7.
// ponytail: suy từ lịch chung của trường; nếu trường đổi mốc học kỳ thì sửa ở đây.
(String, String) yearTermFor(DateTime m) {
  final start = m.month >= 8 ? m.year : m.year - 1;
  final term = (m.month >= 8 || m.month == 1)
      ? 'HK01'
      : (m.month == 7 ? 'HK03' : 'HK02');
  return ('$start-${start + 1}', term);
}

/// Contribution graph của một tháng: mỗi ô một ngày, đậm theo số tiết.
class MonthGraph extends StatefulWidget {
  const MonthGraph({
    super.key,
    required this.session,
    required this.now,
    this.portal,
  });
  final Session session;
  final DateTime now;
  final Portal? portal;

  @override
  State<MonthGraph> createState() => _MonthGraphState();
}

class _MonthGraphState extends State<MonthGraph> with Reloadable<MonthGraph> {
  /// Nạp lại tháng đang xem, ghi đè cache trong bộ nhớ.
  @override
  Future<void> reload() async {
    final m = _month;
    try {
      final days = await _fetch(m);
      if (mounted) setState(() => _cache[_key(m)] = days);
    } on PortalError {
      // giữ nguyên lịch cũ
    }
  }

  /// Lịch đã tải, key là 'năm-tháng'. Tháng trước/sau được nạp sẵn nên bấm
  /// mũi tên là có ngay.
  final _cache = <String, Map<int, List<dynamic>>>{};
  String? _error;
  int? _pick; // ngày đang xem, null = hôm nay
  late DateTime _month = DateTime(widget.now.year, widget.now.month);

  Map<int, List<dynamic>>? get _days => _cache[_key(_month)];
  static String _key(DateTime m) => '${m.year}-${m.month}';

  @override
  void initState() {
    super.initState();
    _show(_month);
  }

  void _goto(DateTime m) {
    setState(() {
      _month = m;
      _error = null;
      _pick = null;
    });
    _show(m);
  }

  Future<void> _show(DateTime m) async {
    if (!await _grab(m)) return;
    for (final n in [
      DateTime(m.year, m.month + 1),
      DateTime(m.year, m.month - 1),
    ]) {
      await _grab(n, quiet: true);
    }
  }

  /// Tải một tháng vào cache, trả về false khi lỗi hoặc widget đã đóng.
  Future<bool> _grab(DateTime m, {bool quiet = false}) async {
    if (_cache.containsKey(_key(m))) return true;
    try {
      final days = await _fetch(m);
      if (!mounted) return false;
      setState(() => _cache[_key(m)] = days);
      return true;
    } on PortalError catch (e) {
      if (mounted && !quiet) setState(() => _error = e.message);
      return false;
    }
  }

  Future<Map<int, List<dynamic>>> _fetch(DateTime month) async {
    final portal = widget.portal ?? Portal();
    final last = DateTime(month.year, month.month + 1, 0);
    final (year, term) = yearTermFor(month);
    final weeks = {
      for (var d = month; !d.isAfter(last); d = d.add(const Duration(days: 1)))
        isoWeek(d),
    };
    final fetched = await Future.wait(
      weeks.map(
        (w) => portal.weekSchedule(
          widget.session.token,
          year: year,
          term: term,
          week: w,
        ),
      ),
    );
    return itemsByDay(fetched.expand((e) => e), month);
  }

  @override
  Widget build(BuildContext context) {
    final month = _month;
    final thisMonth =
        month.year == widget.now.year && month.month == widget.now.month;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = month.weekday - 1; // ô trống trước ngày 1
    final pick = _pick ?? (thisMonth ? widget.now.day : 1);
    return Column(
      children: [
        PaperBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Arrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _goto(DateTime(month.year, month.month - 1)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final m = await showDialog<DateTime>(
                          context: context,
                          builder: (_) => _MonthPicker(month: month),
                        );
                        if (m != null) _goto(m);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Tháng ${month.month}/${month.year}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Baloo',
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Paper.ink,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.expand_more_rounded,
                            size: 20,
                            color: Paper.ink2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Arrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _goto(DateTime(month.year, month.month + 1)),
                  ),
                  const SizedBox(width: 8),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: Paper.ink3, fontSize: 12),
                    )
                  else if (_days == null)
                    const Skeleton(width: 48, height: 12)
                  else
                    Text(
                      '${periods(_days!.values.expand((e) => e))} tiết',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(color: Paper.ink3, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Nhãn thứ để ô trống trước ngày 1 nhìn ra là lịch, không phải
              // khoảng hở thừa.
              Row(
                children: [
                  for (final d in const [
                    'T2',
                    'T3',
                    'T4',
                    'T5',
                    'T6',
                    'T7',
                    'CN',
                  ])
                    Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Paper.ink3,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                // Không đặt thì GridView tự chèn padding bằng status bar,
                // thành ra hở nguyên một hàng phía trên ngày 1.
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                children: [
                  for (var i = 0; i < lead; i++) const SizedBox(),
                  if (_days == null)
                    for (var d = 1; d <= days; d++)
                      const Skeleton(height: 44, radius: 6, ink: true)
                  else
                    for (var d = 1; d <= days; d++)
                      _Cell(
                        day: d,
                        items: _days?[d] ?? const [],
                        today: thisMonth && d == widget.now.day,
                        picked: d == pick,
                        onTap: () => setState(() => _pick = d),
                      ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: const [
                  _Legend(color: _motBuoi, label: '1 buổi'),
                  _Legend(color: _haiBuoi, label: '2 buổi'),
                  _Legend(color: _baBuoi, label: '3 buổi'),
                  _Legend(color: _nghi, label: 'Nghỉ'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DayCard(
          day: DateTime(month.year, month.month, pick),
          items: _days?[pick] ?? const [],
          loading: _days == null && _error == null,
          onToday: thisMonth && pick == widget.now.day
              ? null
              : () => _goto(DateTime(widget.now.year, widget.now.month)),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.items,
    required this.loading,
    required this.onToday,
  });
  final DateTime day;
  final List<dynamic> items;
  final bool loading;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) => PaperBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${dayNames[day.weekday]}, ${day.day}/${day.month}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Baloo',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Paper.ink,
                ),
              ),
            ),
            if (onToday != null)
              PaperButton(
                label: 'Xem ngày hôm nay',
                fontSize: 13,
                color: Paper.sky,
                onColor: Paper.ink,
                onPressed: onToday!,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (loading)
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 190, height: 16),
              SizedBox(height: 10),
              Skeleton(width: 240, height: 24, radius: 12),
              SizedBox(height: 10),
              Skeleton(width: 130, height: 12),
            ],
          )
        else if (items.isEmpty)
          Container(
            color: Paper.sun,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: const Text(
              'Không có tiết',
              style: TextStyle(
                fontFamily: 'Baloo',
                fontWeight: FontWeight.w800,
                fontSize: 30,
                height: 1.25,
                color: Paper.ink,
              ),
            ),
          )
        else
          for (final (n, i) in items.indexed)
            _Lesson(i, delay: Duration(milliseconds: 70 * n)),
      ],
    ),
  );
}

class _Lesson extends StatelessWidget {
  const _Lesson(this.i, {this.delay = Duration.zero});
  final dynamic i;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final dau = tietNo(i['BeginTime']);
    final cuoi = tietNo(i['EndTime']);
    final gio = khungGio(dau, cuoi);
    return PopIn(
      delay: delay,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cột giờ vào - giờ ra, nối bằng một vạch cho ra dáng timeline.
              if (gio != null) ...[
                SizedBox(
                  width: 46,
                  child: Column(
                    children: [
                      Text(
                        gio.$1,
                        style: const TextStyle(
                          fontFamily: 'Baloo',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Paper.ink,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: Paper.ink3,
                          ),
                        ),
                      ),
                      Text(
                        gio.$2,
                        style: const TextStyle(fontSize: 13, color: Paper.ink3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clean(i['CurriculumName']),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Paper.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Pill('Tiết $dau-$cuoi', color: Paper.sun),
                        Pill(buoi(dau), color: Paper.mint),
                        Pill('Phòng ${i['RoomID']}', color: Paper.sky),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GV: ${i['FullName'] ?? '—'}',
                      style: const TextStyle(fontSize: 13, color: Paper.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ô màu + tên buổi trong phần chú thích.
class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Paper.ink, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Paper.ink3, fontSize: 12)),
    ],
  );
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.items,
    required this.today,
    required this.picked,
    required this.onTap,
  });
  final int day;
  final List<dynamic> items;
  final bool today, picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PopIn(
    // Lần lượt từng ngày cho ra hiệu ứng lướt qua tháng.
    delay: Duration(milliseconds: 8 * day),
    child: Pressable(
      onTap: onTap,
      builder: (down) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dayColor(items),
          border: Border.all(color: Paper.ink, width: picked ? 3 : 1.5),
          borderRadius: BorderRadius.circular(6),
          boxShadow: picked ? Paper.shadow(down ? 0 : 2) : null,
        ),
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12,
            color: Paper.ink,
            fontWeight: today ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Paper.card,
        border: Paper.border,
        borderRadius: BorderRadius.circular(10),
        boxShadow: Paper.shadow(2),
      ),
      child: Icon(icon, size: 20, color: Paper.ink),
    ),
  );
}

/// Chọn tháng / năm: một tờ giấy với 12 ô tháng và năm đổi bằng mũi tên.
class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.month});
  final DateTime month;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.month.year;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Paper.paper,
        border: Paper.border,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Paper.shadow(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Arrow(
                icon: Icons.chevron_left_rounded,
                onTap: () => setState(() => _year--),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_year',
                  style: const TextStyle(
                    fontFamily: 'Baloo',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: Paper.ink,
                  ),
                ),
              ),
              _Arrow(
                icon: Icons.chevron_right_rounded,
                onTap: () => setState(() => _year++),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              for (var m = 1; m <= 12; m++)
                GestureDetector(
                  onTap: () => Navigator.pop(context, DateTime(_year, m)),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          m == widget.month.month && _year == widget.month.year
                          ? Paper.sun
                          : Paper.card,
                      border: Paper.border,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: Paper.shadow(2),
                    ),
                    child: Text(
                      'Th $m',
                      style: const TextStyle(
                        fontFamily: 'Baloo',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Paper.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Tiết của hôm nay, tự ẩn nếu hôm nay nghỉ.
class TodayLessons extends StatefulWidget {
  const TodayLessons({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<TodayLessons> createState() => _TodayLessonsState();
}

class _TodayLessonsState extends State<TodayLessons>
    with Reloadable<TodayLessons> {
  @override
  Future<void> reload() => _load();

  List<dynamic>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final (year, term) = yearTermFor(now);
    try {
      final week = await (widget.portal ?? Portal()).weekSchedule(
        widget.session.token,
        year: year,
        term: term,
        week: isoWeek(now),
      );
      final days = itemsByDay(week, DateTime(now.year, now.month));
      if (mounted) setState(() => _items = days[now.day] ?? const []);
    } on PortalError {
      if (mounted) setState(() => _items = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 20),
        child: Skeleton(height: 120, radius: 16, ink: true),
      );
    }
    if (_items!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hôm nay',
            style: TextStyle(
              fontFamily: 'Baloo',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 10),
          PaperBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (n, i) in _items!.indexed)
                  _Lesson(i, delay: Duration(milliseconds: 70 * n)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
