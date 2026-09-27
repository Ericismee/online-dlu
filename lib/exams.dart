import 'package:flutter/material.dart';

import 'data.dart';
import 'graph.dart';
import 'paper.dart';
import 'portal.dart';

/// 'dd/MM/yyyy' của portal.
DateTime parseDMY(String s) {
  final p = s.split('/');
  return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
}

/// Sắp thi (gần nhất trước) rồi mới tới đã thi (mới nhất trước).
List<dynamic> sortExams(Iterable<dynamic> exams, DateTime today) {
  final soon = <dynamic>[], done = <dynamic>[];
  for (final e in exams) {
    (parseDMY(e['NgayThi'] as String).isBefore(today) ? done : soon).add(e);
  }
  soon.sort(
    (a, b) =>
        parseDMY(a['NgayThi'] as String)
            .compareTo(parseDMY(b['NgayThi'] as String)),
  );
  done.sort(
    (a, b) =>
        parseDMY(b['NgayThi'] as String)
            .compareTo(parseDMY(a['NgayThi'] as String)),
  );
  return [...soon, ...done];
}

/// StudyUnitID kiểu '251QP2101D': 2 số năm + 1 số học kỳ.
/// API không lọc theo năm/kỳ nên phải tự lọc ở máy.
(String, String)? examTerm(dynamic e) {
  final id = e['StudyUnitID'] as String? ?? '';
  final y = int.tryParse(id.length >= 3 ? id.substring(0, 2) : '');
  final t = int.tryParse(id.length >= 3 ? id.substring(2, 3) : '');
  if (y == null || t == null) return null;
  return ('${2000 + y}-${2001 + y}', 'HK0$t');
}

class ExamsTab extends StatefulWidget {
  const ExamsTab({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<ExamsTab> createState() => _ExamsTabState();
}

class _ExamsTabState extends State<ExamsTab> with Reloadable<ExamsTab> {
  @override
  Future<void> reload() => _load();

  List<dynamic>? _exams;
  String? _error;
  late (String, String) _pick = yearTermFor(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await (widget.portal ?? Portal()).exams(widget.session.token);
      if (mounted) setState(() => _exams = e);
    } on PortalError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final all = _exams ?? const <dynamic>[];
    final list = sortExams(
      all.where((e) => examTerm(e) == _pick),
      DateTime(today.year, today.month, today.day),
    );
    // Có năm hiện tại cố định trong danh sách: chọn năm cũ rồi vẫn quay lại
    // được, chứ không phải chọn xong là năm mới biến mất khỏi menu.
    final years = {
      ...all.map((e) => examTerm(e)?.$1).nonNulls,
      yearTermFor(today).$1,
      _pick.$1,
    }.toList()..sort((a, b) => b.compareTo(a));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: PullRefresh(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 20,
              20,
              MediaQuery.paddingOf(context).bottom + 110,
            ),
            children: [
              const Text(
                'Lịch thi',
                style: TextStyle(
                  fontFamily: 'Baloo',
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                  color: Paper.ink,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Choice(
                    label: _pick.$1,
                    onTap: () async {
                      final y = await chooseOption(context, years, _pick.$1);
                      if (y != null) setState(() => _pick = (y, _pick.$2));
                    },
                  ),
                  const SizedBox(width: 8),
                  Choice(
                    label: _pick.$2,
                    color: Paper.mint,
                    onTap: () async {
                      final t = await chooseOption(context, const [
                        'HK01',
                        'HK02',
                        'HK03',
                      ], _pick.$2);
                      if (t != null) setState(() => _pick = (_pick.$1, t));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null)
                PaperBox(
                  color: Paper.rose,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Paper.ink),
                  ),
                )
              else if (_exams == null)
                for (var i = 0; i < 4; i++)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Skeleton(height: 96, radius: 16, ink: true),
                  )
              else if (list.isEmpty)
                Container(
                  color: Paper.sun,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  child: const Text(
                    'Không có lịch thi',
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
                for (final e in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ExamCard(e, today: today),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ một ca thi, dùng ở tab Thi và Trang chủ.
class ExamCard extends StatelessWidget {
  const ExamCard(this.e, {super.key, required this.today});
  final dynamic e;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final day = parseDMY(e['NgayThi'] as String);
    final past = day.isBefore(DateTime(today.year, today.month, today.day));
    return PaperBox(
      color: past ? Paper.card : Paper.rose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clean(e['CurriculumName']),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                '${dayNames[day.weekday]} ${e['NgayThi']}',
                color: Paper.sun,
              ),
              Pill('${e['GioThi']}', color: Paper.mint),
              Pill('Phòng ${e['PhongThi']}', color: Paper.sky),
              Pill('${e['ThoiLuong']} phút', color: Paper.peach),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${e['HinhThucThi']} · ${e['LanThi']} · ${e['KyThi']}',
            style: const TextStyle(fontSize: 13, color: Paper.ink2),
          ),
        ],
      ),
    );
  }
}
