import 'package:flutter/material.dart';

import 'data.dart';
import 'paper.dart';
import 'portal.dart';

/// Đạt thì xanh, chưa đạt thì hồng, chưa có điểm thì để trắng.
Color markColor(dynamic m) => m['DiemTK_10'] == null || m['DiemTK_10'] == ''
    ? Paper.card
    : (m['IsPass'] == 'x' ? Paper.mint : Paper.rose);

/// Ô trống của portal về null, hiện gạch cho dễ nhìn.
String show(Object? v) => (v == null || v == '') ? '—' : clean(v);

/// Danh sách (năm học, học kỳ) có trong bảng điểm, mới nhất trước.
List<(String, String)> termKeys(List<dynamic> years) => [
  for (final y in years.reversed)
    for (final t in (y['DanhSachDiem'] as List).reversed)
      (clean(y['NamHoc']), clean(t['HocKy'])),
];

/// Các môn của một kỳ.
List<dynamic> subjectsOf(List<dynamic> years, (String, String) key) {
  for (final y in years) {
    if (y['NamHoc'] != key.$1) continue;
    for (final t in y['DanhSachDiem'] as List) {
      if (t['HocKy'] == key.$2) {
        return (t['DanhSachDiemHK'] as List?) ?? const [];
      }
    }
  }
  return const [];
}

/// Kỳ mới nhất đã có điểm, để mở ra không thấy trống trơn.
(String, String) latestScored(List<dynamic> years) {
  final keys = termKeys(years);
  return keys.firstWhere(
    (k) => subjectsOf(years, k).any((m) => m['TB_HK_10'] != null),
    orElse: () => keys.first,
  );
}

/// Bảng điểm theo năm học / học kỳ.
class MarksScreen extends StatefulWidget {
  const MarksScreen({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen>
    with Reloadable<MarksScreen> {
  @override
  Future<void> reload() => _load();

  List<dynamic>? _years;
  (String, String)? _pick;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final portal = widget.portal ?? Portal();
    try {
      final program = await portal.studyProgram(widget.session.token);
      final years = await portal.marks(widget.session.token, program);
      if (mounted) {
        setState(() {
          _years = years;
          if (years.isNotEmpty) _pick = latestScored(years);
        });
      }
    } on PortalError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final years = _years ?? const [];
    final keys = years.isEmpty ? const <(String, String)>[] : termKeys(years);
    final pick = _pick;
    final subjects = pick == null ? const [] : subjectsOf(years, pick);
    return Scaffold(
      body: DotBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: PullRefresh(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 20,
                  20,
                  40,
                ),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Điểm',
                          style: TextStyle(
                            fontFamily: 'Baloo',
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                            color: Paper.ink,
                          ),
                        ),
                      ),
                      PaperButton(
                        label: 'Quay lại',
                        color: Paper.card,
                        onColor: Paper.ink,
                        onPressed: () => Navigator.pop(context),
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
                  else if (_years == null) ...[
                    const Skeleton(height: 110, radius: 16, ink: true),
                    const SizedBox(height: 16),
                    const Skeleton(height: 240, radius: 16, ink: true),
                  ] else if (pick == null)
                    PaperBox(
                      child: Container(
                        color: Paper.sun,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: const Text(
                          'Chưa có điểm',
                          style: TextStyle(
                            fontFamily: 'Baloo',
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                            color: Paper.ink,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    TotalCard(
                      record: subjectsOf(years, keys.first).firstOrNull,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Choice(
                          label: pick.$1,
                          onTap: () async {
                            final y = await chooseOption(
                              context,
                              {for (final k in keys) k.$1}.toList(),
                              pick.$1,
                            );
                            if (y == null) return;
                            setState(
                              () => _pick = keys.firstWhere(
                                (k) => k.$1 == y && k.$2 == pick.$2,
                                orElse: () => keys.firstWhere((k) => k.$1 == y),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Choice(
                          label: pick.$2,
                          color: Paper.mint,
                          onTap: () async {
                            final t = await chooseOption(context, [
                              for (final k in keys)
                                if (k.$1 == pick.$1) k.$2,
                            ], pick.$2);
                            if (t != null) setState(() => _pick = (pick.$1, t));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Term(year: pick.$1, term: pick.$2, subjects: subjects),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tổng kết toàn khoá, đọc từ bản ghi mới nhất.
class TotalCard extends StatelessWidget {
  const TotalCard({super.key, required this.record});
  final dynamic record;

  @override
  Widget build(BuildContext context) => PaperBox(
    color: Paper.sun,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tích luỹ toàn khoá',
          style: TextStyle(
            fontFamily: 'Baloo',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Paper.ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Pill('GPA ${show(record?['TB_TL_TN'])}/4', color: Paper.card),
            Pill('${show(record?['T_TC_TL_TN'])} TC', color: Paper.mint),
            Pill(show(record?['TenXepLoai']), color: Paper.sky),
          ],
        ),
      ],
    ),
  );
}

class _Term extends StatelessWidget {
  const _Term({required this.year, required this.term, required this.subjects});
  final String year;
  final String term;
  final List<dynamic> subjects;

  @override
  Widget build(BuildContext context) {
    final first = subjects.isEmpty ? null : subjects.first;
    final scored = subjects.any((m) => m['DiemTK_10'] != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$year · $term',
                style: const TextStyle(
                  fontFamily: 'Baloo',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Paper.ink,
                ),
              ),
            ),
            if (first != null && scored)
              Pill('TB ${show(first['TB_HK_10'])} · ${show(first['TB_HK_4'])}'),
          ],
        ),
        const SizedBox(height: 8),
        PaperBox(
          child: scored
              ? Column(children: [for (final m in subjects) _Mark(m)])
              : Container(
                  color: Paper.sun,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: const Text(
                    'Chưa có điểm',
                    style: TextStyle(
                      fontFamily: 'Baloo',
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      color: Paper.ink,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark(this.m);
  final dynamic m;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clean(m['CurriculumName']),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Paper.ink,
                ),
              ),
              Text(
                '${m['Credits']} TC',
                style: const TextStyle(fontSize: 12, color: Paper.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Pill(
          '${show(m['DiemTK_10'])} · ${show(m['DiemTK_Chu'])}',
          color: markColor(m),
        ),
      ],
    ),
  );
}

/// Thẻ tích luỹ tự nạp dữ liệu, dùng ở Trang chủ.
class TotalSummary extends StatefulWidget {
  const TotalSummary({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<TotalSummary> createState() => _TotalSummaryState();
}

class _TotalSummaryState extends State<TotalSummary>
    with Reloadable<TotalSummary> {
  @override
  Future<void> reload() => _load();

  dynamic _record;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final portal = widget.portal ?? Portal();
    try {
      final program = await portal.studyProgram(widget.session.token);
      final years = await portal.marks(widget.session.token, program);
      final r = years.isEmpty
          ? null
          : subjectsOf(years, termKeys(years).first).firstOrNull;
      if (mounted) setState(() => _record = r);
    } on PortalError {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _record == null
          ? const Skeleton(height: 110, radius: 16, ink: true)
          : TotalCard(record: _record),
    );
  }
}
