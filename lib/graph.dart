import 'package:flutter/material.dart';

import 'paper.dart';
import 'portal.dart';

/// Tuần ISO của một ngày — portal đánh số tuần theo chuẩn này (21/09/2026 = 39).
int isoWeek(DateTime d) {
  final thu = d.add(Duration(days: 4 - d.weekday));
  return thu.difference(DateTime(thu.year, 1, 1)).inDays ~/ 7 + 1;
}

/// Tổng số tiết mỗi ngày, gom từ các item lịch tuần. Key = ngày trong tháng.
Map<int, int> periodsByDay(Iterable<dynamic> items, DateTime month) {
  final out = <int, int>{};
  for (final i in items) {
    final p = (i['StartDate'] as String).split('/'); // dd/MM/yyyy của thứ 2
    final monday = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    final day = monday.add(Duration(days: (i['DayOfWeek'] as int) - 1));
    if (day.year != month.year || day.month != month.month) continue;
    out[day.day] = (out[day.day] ?? 0) + (i['NumberOfPeriods'] as int);
  }
  return out;
}

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
  Map<int, int>? _days;
  String? _error;

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
        setState(() => _days = periodsByDay(fetched.expand((e) => e), month));
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
    return PaperBox(
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
                Text('${_days!.values.fold(0, (a, b) => a + b)} tiết',
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
                _Cell(day: d, periods: _days?[d] ?? 0, today: d == widget.now.day),
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
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.day, required this.periods, required this.today});
  final int day, periods;
  final bool today;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _level(periods),
          border: Border.all(color: Paper.ink, width: today ? 3 : 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$day',
            style: TextStyle(
                fontSize: 12,
                color: Paper.ink,
                fontWeight: today ? FontWeight.w800 : FontWeight.w600)),
      );
}
