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
    final day = monday.add(Duration(days: (i['DayOfWeek'] as int) - 1));
    if (day.year != month.year || day.month != month.month) continue;
    out.putIfAbsent(day.day, () => []).add(i);
  }
  for (final l in out.values) {
    l.sort((a, b) => (a['PeriodID'] as int) - (b['PeriodID'] as int));
  }
  return out;
}

int periods(Iterable<dynamic> items) =>
    items.fold(0, (a, i) => a + (i['NumberOfPeriods'] as int));

/// Tiết 1-5 sáng, 6-10 chiều, còn lại tối.
String buoi(int periodID) =>
    periodID <= 5 ? 'Sáng' : (periodID <= 10 ? 'Chiều' : 'Tối');

/// Ô càng đậm càng nhiều tiết.
Color _level(int periods) => switch (periods) {
  0 => const Color(0xFFF2E7CE),
  <= 4 => Paper.mint,
  <= 8 => Paper.sun,
  <= 12 => Paper.peach,
  _ => Paper.accent,
};

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

class _MonthGraphState extends State<MonthGraph> {
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
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
                        periods: periods(_days?[d] ?? const []),
                        today: thisMonth && d == widget.now.day,
                        picked: d == pick,
                        onTap: () => setState(() => _pick = d),
                      ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Ít',
                    style: TextStyle(color: Paper.ink3, fontSize: 12),
                  ),
                  for (final p in [0, 4, 8, 12, 16])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _level(p),
                          border: Border.all(color: Paper.ink, width: 1.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  const Text(
                    'Nhiều',
                    style: TextStyle(color: Paper.ink3, fontSize: 12),
                  ),
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
                label: 'Hôm nay',
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
          for (final i in items) _Lesson(i),
      ],
    ),
  );
}

class _Lesson extends StatelessWidget {
  const _Lesson(this.i);
  final dynamic i;

  @override
  Widget build(BuildContext context) {
    final tiet = '${i['BeginTime']}-${i['EndTime']}'.replaceAll('Tiết: ', '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i['CurriculumName'] as String? ?? '',
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
              Pill('Tiết $tiet', color: Paper.sun),
              Pill(buoi(i['PeriodID'] as int), color: Paper.mint),
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
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.periods,
    required this.today,
    required this.picked,
    required this.onTap,
  });
  final int day, periods;
  final bool today, picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _level(periods),
        border: Border.all(color: Paper.ink, width: picked ? 3 : 1.5),
        borderRadius: BorderRadius.circular(6),
        boxShadow: picked ? Paper.shadow(2) : null,
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

class _TodayLessonsState extends State<TodayLessons> {
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
              children: [for (final i in _items!) _Lesson(i)],
            ),
          ),
        ],
      ),
    );
  }
}
