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

/// Contribution graph của tháng hiện tại: mỗi ô một ngày, đậm theo số tiết.
class MonthGraph extends StatefulWidget {
  const MonthGraph({super.key, required this.session, required this.now, this.portal});
  final Session session;
  final DateTime now;
  final Portal? portal;

  @override
  State<MonthGraph> createState() => _MonthGraphState();
}

class _MonthGraphState extends State<MonthGraph> {
  Map<int, List<dynamic>>? _days;
  String? _error;
  int? _pick; // ngày đang xem, null = hôm nay

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final portal = widget.portal ?? Portal();
    final token = widget.session.token;
    final month = DateTime(widget.now.year, widget.now.month);
    final last = DateTime(month.year, month.month + 1, 0);
    try {
      final (year, term) = await portal.yearAndTerm(token);
      final weeks = {
        for (var d = month; !d.isAfter(last); d = d.add(const Duration(days: 1)))
          isoWeek(d)
      };
      final fetched = await Future.wait(weeks.map((w) =>
          portal.weekSchedule(token, year: year, term: term, week: w)));
      if (mounted) {
        setState(() => _days = itemsByDay(fetched.expand((e) => e), month));
      }
    } on PortalError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = DateTime(widget.now.year, widget.now.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = month.weekday - 1; // ô trống trước ngày 1
    final pick = _pick ?? widget.now.day;
    return Column(children: [
      PaperBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Tháng ${month.month}/${month.year}',
                    style: const TextStyle(
                        fontFamily: 'Baloo',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Paper.ink)),
              ),
              if (_error != null)
                Text(_error!,
                    style: const TextStyle(color: Paper.ink3, fontSize: 12))
              else if (_days == null)
                const Text('Đang tải…',
                    style: TextStyle(color: Paper.ink3, fontSize: 12))
              else
                Text('${periods(_days!.values.expand((e) => e))} tiết',
                    style: const TextStyle(color: Paper.ink3, fontSize: 12)),
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
              for (var d = 1; d <= days; d++)
                _Cell(
                    day: d,
                    periods: periods(_days?[d] ?? const []),
                    today: d == widget.now.day,
                    picked: d == (_pick ?? widget.now.day),
                    onTap: () => setState(() => _pick = d)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Ít',
                  style: TextStyle(color: Paper.ink3, fontSize: 12)),
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
              const Text('Nhiều',
                  style: TextStyle(color: Paper.ink3, fontSize: 12)),
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
          onToday: pick == widget.now.day
              ? null
              : () => setState(() => _pick = null)),
    ]);
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard(
      {required this.day,
      required this.items,
      required this.loading,
      required this.onToday});
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
                          color: Paper.ink)),
                ),
                if (onToday != null)
                  PaperButton(
                      label: 'Hôm nay',
                      color: Paper.sky,
                      onColor: Paper.ink,
                      onPressed: onToday!),
              ],
            ),
            const SizedBox(height: 10),
            if (loading)
              const Text('Đang tải…',
                  style: TextStyle(color: Paper.ink3, fontSize: 14))
            else if (items.isEmpty)
              const Text('Nghỉ 🎉',
                  style: TextStyle(color: Paper.ink2, fontSize: 15))
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
          Text(i['CurriculumName'] as String? ?? '',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Paper.ink)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Pill('Tiết $tiet', color: Paper.sun),
            Pill(buoi(i['PeriodID'] as int), color: Paper.mint),
            Pill('Phòng ${i['RoomID']}', color: Paper.sky),
          ]),
          const SizedBox(height: 4),
          Text('GV: ${i['FullName'] ?? '—'}',
              style: const TextStyle(fontSize: 13, color: Paper.ink2)),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
      {required this.day,
      required this.periods,
      required this.today,
      required this.picked,
      required this.onTap});
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
        child: Text('$day',
            style: TextStyle(
                fontSize: 12,
                color: Paper.ink,
                fontWeight: today ? FontWeight.w800 : FontWeight.w600)),
        ),
      );
}
