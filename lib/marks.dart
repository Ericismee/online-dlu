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

/// Thang 4 của trường: A 4.0 · B+ 3.5 · B 3.0 · C+ 2.5 · C 2.0 · D+ 1.5 ·
/// D 1.0 · F 0. Dùng để đoán GPA, còn điểm thật vẫn lấy từ portal.
// ponytail: mốc quy đổi theo quy chế tín chỉ; trường đổi thang thì sửa ở đây.
const thang4 = <(String, double)>[
  ('A', 4.0),
  ('B+', 3.5),
  ('B', 3.0),
  ('C+', 2.5),
  ('C', 2.0),
  ('D+', 1.5),
  ('D', 1.0),
  ('F', 0.0),
];

/// GPA sau khi cộng thêm mấy môn chưa có điểm: [them] là (số tín chỉ, điểm hệ 4).
/// Trả về (GPA dự kiến, tổng tín chỉ tích luỹ dự kiến).
(double, int) gpaDuBao({
  required double gpa,
  required int tc,
  required List<(int, double)> them,
}) {
  final tcThem = them.fold(0, (a, e) => a + e.$1);
  if (tcThem == 0) return (gpa, tc);
  final diem = them.fold(0.0, (a, e) => a + e.$1 * e.$2);
  return ((gpa * tc + diem) / (tc + tcThem), tc + tcThem);
}

/// Môn của một kỳ chưa có điểm, bỏ học phần điều kiện vì không tính điểm TB.
List<dynamic> chuaCoDiem(List<dynamic> subjects) => [
  for (final m in subjects)
    if ((m['DiemTK_10'] == null || m['DiemTK_10'] == '') &&
        !isCondition(m['CurriculumName']))
      m,
];

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
  String _q = '';

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
          _error = null;
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
    final all = pick == null ? const [] : subjectsOf(years, pick);
    final subjects = [
      for (final m in all)
        if (khop(subjectName(m['CurriculumName']), _q)) m,
    ];
    // Mở từ thanh đáy thì không có gì để pop, và phải chừa chỗ cho thanh đó.
    final pop = Navigator.of(context).canPop();
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
                  MediaQuery.paddingOf(context).bottom + (pop ? 40 : 110),
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
                      if (pop)
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
                    if (chuaCoDiem(all).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PaperButton(
                          label: 'Thử GPA',
                          fontSize: 14,
                          color: Paper.sky,
                          onColor: Paper.ink,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => WhatIfScreen(
                                term: '${pick.$1} · ${pick.$2}',
                                subjects: chuaCoDiem(all),
                                record: subjectsOf(
                                  years,
                                  keys.first,
                                ).firstOrNull,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                            // Luôn có đủ ba kỳ: học hè là HK03, portal chỉ
                            // trả kỳ đã có điểm nên không thể lấy từ dữ liệu.
                            final t = await chooseOption(context, const [
                              'HK01',
                              'HK02',
                              'HK03',
                            ], pick.$2);
                            if (t != null) setState(() => _pick = (pick.$1, t));
                          },
                        ),
                      ],
                    ),
                    // Kỳ nào cũng hơn chục môn, cuộn tìm một môn khá mệt.
                    if (all.length > 5) ...[
                      const SizedBox(height: 12),
                      SearchBox(
                        hint: 'Tìm môn',
                        onChanged: (v) => setState(() => _q = v),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _Term(
                      year: pick.$1,
                      term: pick.$2,
                      subjects: subjects,
                      timKhongThay: subjects.isEmpty && all.isNotEmpty,
                    ),
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
  const _Term({
    required this.year,
    required this.term,
    required this.subjects,
    this.timKhongThay = false,
  });
  final String year;
  final String term;
  final List<dynamic> subjects;

  /// Kỳ có môn nhưng chữ đang tìm không khớp môn nào.
  final bool timKhongThay;

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
          child: timKhongThay
              ? const Text(
                  'Không có môn nào khớp.',
                  style: TextStyle(color: Paper.ink2),
                )
              // Kỳ đang học chưa có điểm nhưng đã có môn: cứ hiện tên môn,
              // ô điểm để '—' là đủ hiểu.
              : subjects.isNotEmpty
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
                subjectName(m['CurriculumName']),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Paper.ink,
                ),
              ),
              Text(
                isCondition(m['CurriculumName'])
                    ? '${toNum(m['Credits'])} TC · không tính điểm TB'
                    : '${toNum(m['Credits'])} TC',
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

/// Thử GPA: chọn điểm dự kiến cho mấy môn chưa có điểm, xem tích luỹ đi tới đâu.
class WhatIfScreen extends StatefulWidget {
  const WhatIfScreen({
    super.key,
    required this.term,
    required this.subjects,
    required this.record,
  });
  final String term;
  final List<dynamic> subjects;

  /// Bản ghi mới nhất, lấy GPA và số tín chỉ đang tích luỹ.
  final dynamic record;

  @override
  State<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends State<WhatIfScreen> {
  /// Chỉ số môn -> điểm chữ đã chọn. Chưa chọn thì không tính vào dự báo.
  final _chon = <int, String>{};

  double get _gpa => toNum(widget.record?['TB_TL_TN']).toDouble();
  int get _tc => toNum(widget.record?['T_TC_TL_TN']).toInt();

  List<(int, double)> get _them => [
    for (final e in _chon.entries)
      (
        toNum(widget.subjects[e.key]['Credits']).toInt(),
        thang4.firstWhere((g) => g.$1 == e.value).$2,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final (gpa, tc) = gpaDuBao(gpa: _gpa, tc: _tc, them: _them);
    return Scaffold(
      body: DotBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 20,
                20,
                MediaQuery.paddingOf(context).bottom + 40,
              ),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Thử GPA',
                        style: TextStyle(
                          fontFamily: 'Baloo',
                          fontWeight: FontWeight.w800,
                          fontSize: 30,
                          color: Paper.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PaperButton(
                      label: 'Quay lại',
                      color: Paper.card,
                      onColor: Paper.ink,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.term} · số dự đoán, không phải điểm thật',
                  style: const TextStyle(fontSize: 13, color: Paper.ink3),
                ),
                const SizedBox(height: 16),
                PaperBox(
                  color: _chon.isEmpty ? Paper.card : Paper.sun,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GPA dự kiến ${gpa.toStringAsFixed(2)}/4',
                        style: const TextStyle(
                          fontFamily: 'Baloo',
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          color: Paper.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Pill(
                            'Hiện ${_gpa.toStringAsFixed(2)}',
                            color: Paper.card,
                          ),
                          Pill('$tc TC', color: Paper.mint),
                          Pill(
                            '${_chon.length}/${widget.subjects.length} môn đã đoán',
                            color: Paper.sky,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PaperBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (n, m) in widget.subjects.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subjectName(m['CurriculumName']),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Paper.ink,
                                      ),
                                    ),
                                    Text(
                                      '${toNum(m['Credits'])} TC',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Paper.ink3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Choice(
                                label: _chon[n] ?? '—',
                                color: _chon[n] == null
                                    ? Paper.card
                                    : Paper.mint,
                                onTap: () async {
                                  final g = await chooseOption(context, [
                                    '—',
                                    for (final t in thang4) t.$1,
                                  ], _chon[n] ?? '—');
                                  if (g == null) return;
                                  setState(() {
                                    if (g == '—') {
                                      _chon.remove(n);
                                    } else {
                                      _chon[n] = g;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
