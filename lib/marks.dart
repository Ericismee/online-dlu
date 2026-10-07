import 'package:flutter/material.dart';

import 'data.dart';
import 'news.dart';
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

/// Điểm hệ 4 của một môn đã có điểm chữ, null nếu điểm chữ lạ/chưa có.
double? he4Cua(dynamic m) {
  final chu = clean(m['DiemTK_Chu']);
  for (final g in thang4) {
    if (g.$1 == chu) return g.$2;
  }
  return null;
}

/// Môn đã có điểm nhưng còn thấp (dưới B, hệ 4 < 3.0) — ứng viên học cải
/// thiện để nâng GPA. Bỏ học phần điều kiện vì không tính vào điểm TB.
List<dynamic> canCaiThien(List<dynamic> subjects) => [
  for (final m in subjects)
    if (!isCondition(m['CurriculumName']) && (he4Cua(m) ?? 4.0) < 3.0) m,
];

/// Một gợi ý học cải thiện: môn nào, kỳ nào, và GPA nhích lên bao nhiêu nếu
/// học lại được điểm mong muốn.
typedef GoiY = ({String ky, dynamic mon, double he4, int tc, double tang});

/// Xếp môn điểm thấp theo mức đang kéo GPA xuống — môn nhiều tín chỉ mà điểm
/// càng thấp thì kéo càng mạnh, học lại được nó GPA nhích nhiều nhất.
/// Học lại chỉ thay điểm chứ không cộng thêm tín chỉ tích luỹ, nên phần nhích
/// lên đúng bằng chênh điểm nhân tín chỉ rồi chia tổng tín chỉ [tcTichLuy].
List<GoiY> goiYCaiThien(
  List<dynamic> years, {
  required int tcTichLuy,
  double muc = 4.0,
}) {
  if (tcTichLuy <= 0) return const [];
  return [
    for (final k in termKeys(years))
      for (final m in canCaiThien(subjectsOf(years, k)))
        if (he4Cua(m)! < muc)
          (
            ky: '${k.$1} · ${k.$2}',
            mon: m,
            he4: he4Cua(m)!,
            tc: toNum(m['Credits']).toInt(),
            tang: toNum(m['Credits']).toInt() * (muc - he4Cua(m)!) / tcTichLuy,
          ),
  ]..sort((a, b) => b.tang.compareTo(a.tang));
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
                  MediaQuery.paddingOf(context).bottom +
                      (pop ? 40 : chuaThanhDuoi),
                ),
                children: [
                  TieuDeTrang(
                    'Điểm',
                    session: widget.session,
                    phai: pop
                        ? PaperButton(
                            label: 'Quay lại',
                            color: Paper.card,
                            onColor: Paper.ink,
                            onPressed: () => Navigator.pop(context),
                          )
                        : null,
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
                    const Skeleton(height: 110, ink: true),
                    const SizedBox(height: 16),
                    const Skeleton(height: 240, ink: true),
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
                            fontFamily: 'Display',
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
            fontFamily: 'Display',
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
                  fontFamily: 'Display',
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
                      fontFamily: 'Display',
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
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pill('${toNum(m['Credits'])} TC', color: Paper.sun),
                  if (isCondition(m['CurriculumName']))
                    const Pill('Không tính TB', color: Paper.card),
                ],
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
                          fontFamily: 'Display',
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
                  style: const TextStyle(fontSize: 13, color: Paper.ink2),
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
                          fontFamily: 'Display',
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
                                    const SizedBox(height: 6),
                                    Pill(
                                      '${toNum(m['Credits'])} TC',
                                      color: Paper.sun,
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

/// Cải thiện GPA: nơi gợi ý, không phải máy tính. Tự xếp hạng môn đang kéo
/// GPA xuống mạnh nhất và chọn sẵn mấy môn đáng học lại nhất; thêm được môn
/// tự do (chưa học) để xem học thêm thì GPA đi tới đâu.
class ImprovementScreen extends StatefulWidget {
  const ImprovementScreen({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<ImprovementScreen> createState() => _ImprovementScreenState();
}

class _ImprovementScreenState extends State<ImprovementScreen> {
  /// Số môn chọn sẵn khi mở màn — vừa đủ thành một kế hoạch, không ngợp.
  static const _goiYSan = 3;

  List<dynamic>? _years;
  String? _error;

  /// Điểm nhắm tới khi học lại: một nút chung cho cả màn, chọn từng môn thì
  /// lại thành bảng tính chứ không còn là gợi ý.
  String _muc = 'A';

  /// Môn đang nằm trong kế hoạch, theo khoá kỳ+tên nên đổi [_muc] làm đảo thứ
  /// tự cũng không chọn nhầm sang môn khác.
  Set<String>? _chon;

  /// Môn tự do thêm vào để thử: (tên, số tín chỉ, điểm chữ).
  final _tuDo = <(String, int, String)>[];

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
        });
      }
    } on PortalError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  static String _khoa(GoiY g) => '${g.ky}|${g.mon['CurriculumName']}';

  double get _mucHe4 => thang4.firstWhere((g) => g.$1 == _muc).$2;

  dynamic get _record {
    final keys = termKeys(_years ?? const []);
    return keys.isEmpty ? null : subjectsOf(_years!, keys.first).firstOrNull;
  }

  double get _gpa => toNum(_record?['TB_TL_TN']).toDouble();
  int get _tc => toNum(_record?['T_TC_TL_TN']).toInt();

  List<GoiY> get _goiY =>
      goiYCaiThien(_years ?? const [], tcTichLuy: _tc, muc: _mucHe4);

  /// GPA và tín chỉ sau khi học lại mấy môn đã chọn rồi học thêm môn tự do.
  (double, int) _duBao(List<GoiY> goiY) {
    final chon = _chon ?? const {};
    var gpa = _gpa;
    for (final g in goiY) {
      if (chon.contains(_khoa(g))) gpa += g.tang;
    }
    return gpaDuBao(
      gpa: gpa,
      tc: _tc,
      them: [
        for (final (_, tc, diem) in _tuDo)
          (tc, thang4.firstWhere((g) => g.$1 == diem).$2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final goiY = _goiY;
    // Lần đầu có dữ liệu thì chọn sẵn mấy môn nặng ký nhất — mở ra là đã có
    // sẵn một lời khuyên chứ không phải cái danh sách trống chờ bấm. Phải đợi
    // tới lúc có điểm, chứ gán ngay lúc còn đang tải thì chốt luôn tập rỗng.
    if (_chon == null && _years != null) {
      _chon = {for (final g in goiY.take(_goiYSan)) _khoa(g)};
    }
    final chon = _chon ?? const <String>{};
    final (gpa, tc) = _duBao(goiY);
    final max = goiY.isEmpty ? 1.0 : goiY.first.tang;
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
                        'Cải thiện',
                        style: TextStyle(
                          fontFamily: 'Display',
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
                const Text(
                  'Môn nào đang kéo GPA xuống nhiều nhất thì gợi ý trước — '
                  'số dự đoán, không phải điểm thật',
                  style: TextStyle(fontSize: 13, color: Paper.ink2),
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
                  const Skeleton(height: 120, ink: true),
                  const SizedBox(height: 16),
                  const Skeleton(height: 260, ink: true),
                ] else ...[
                  _KeHoach(
                    gpa: _gpa,
                    moi: gpa,
                    tc: tc,
                    soMon: chon.length + _tuDo.length,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Học lại được',
                        style: TextStyle(fontSize: 13, color: Paper.ink2),
                      ),
                      const SizedBox(width: 8),
                      Choice(
                        label: _muc,
                        color: Paper.mint,
                        onTap: () async {
                          final g = await chooseOption(context, const [
                            'A',
                            'B+',
                            'B',
                          ], _muc);
                          if (g != null) setState(() => _muc = g);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (goiY.isEmpty)
                    PaperBox(
                      color: Paper.mint,
                      child: const Text(
                        'Không có môn nào dưới B — chưa cần cải thiện môn nào.',
                        style: TextStyle(
                          fontFamily: 'Display',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Paper.ink,
                        ),
                      ),
                    )
                  else ...[
                    const Text(
                      'Nên ưu tiên',
                      style: TextStyle(
                        fontFamily: 'Display',
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: Paper.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final (n, g) in goiY.indexed) ...[
                      _GoiYCard(
                        hang: n + 1,
                        goiY: g,
                        phan: max <= 0 ? 0 : g.tang / max,
                        keoXuong: g.he4 < _gpa,
                        chon: chon.contains(_khoa(g)),
                        onTap: () => setState(() {
                          final k = _khoa(g);
                          final s = _chon ??= <String>{};
                          s.contains(k) ? s.remove(k) : s.add(k);
                        }),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Môn tự do',
                    style: TextStyle(
                      fontFamily: 'Display',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: Paper.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Môn chưa học, thêm vào xem có kéo GPA lên được không',
                    style: TextStyle(fontSize: 13, color: Paper.ink2),
                  ),
                  const SizedBox(height: 8),
                  if (_tuDo.isNotEmpty)
                    PaperBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (n, m) in _tuDo.indexed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.$1,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Paper.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            Pill(
                                              '${m.$2} TC',
                                              color: Paper.sun,
                                            ),
                                            Pill(
                                              'Dự kiến ${m.$3}',
                                              color: Paper.mint,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Pressable(
                                    onTap: () =>
                                        setState(() => _tuDo.removeAt(n)),
                                    builder: (_) => const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                        color: Paper.ink3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_tuDo.isNotEmpty) const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PaperButton(
                      label: '+ Thêm môn tự do',
                      fontSize: 14,
                      color: Paper.peach,
                      onColor: Paper.ink,
                      onPressed: _themMonTuDo,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _themMonTuDo() async {
    final ten = TextEditingController();
    final tc = TextEditingController(text: '3');
    var diem = 'A';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Paper.paper,
              border: Paper.border,
              borderRadius: BorderRadius.all(Paper.radius),
              boxShadow: Paper.shadow(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thêm môn tự do',
                  style: TextStyle(
                    fontFamily: 'Display',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Paper.ink,
                  ),
                ),
                const SizedBox(height: 14),
                _O(
                  child: TextField(
                    controller: ten,
                    autofocus: true,
                    style: const TextStyle(
                      fontFamily: 'Display',
                      fontWeight: FontWeight.w700,
                      color: Paper.ink,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Tên môn (vd: Tiếng Anh 2)',
                      hintStyle: TextStyle(
                        fontFamily: 'Display',
                        fontWeight: FontWeight.w700,
                        color: Paper.ink2,
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _O(
                  child: TextField(
                    controller: tc,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Paper.ink),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Số tín chỉ',
                      hintStyle: TextStyle(color: Paper.ink2),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Choice(
                  label: 'Điểm dự kiến $diem',
                  color: Paper.mint,
                  onTap: () async {
                    final g = await chooseOption(ctx, [
                      for (final t in thang4) t.$1,
                    ], diem);
                    if (g != null) setState(() => diem = g);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PaperButton(
                      label: 'Huỷ',
                      color: Paper.card,
                      onColor: Paper.ink,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                    const SizedBox(width: 8),
                    PaperButton(
                      label: 'Thêm',
                      color: Paper.sun,
                      onColor: Paper.ink,
                      onPressed: () {
                        if (ten.text.trim().isEmpty) return;
                        if ((int.tryParse(tc.text.trim()) ?? 0) <= 0) return;
                        Navigator.pop(ctx, true);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    setState(
      () => _tuDo.add((ten.text.trim(), int.parse(tc.text.trim()), diem)),
    );
  }
}

/// Ô nhập kiểu giấy cho hộp thoại thêm môn tự do.
class _O extends StatelessWidget {
  const _O({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Paper.card,
      border: Paper.border,
      borderRadius: BorderRadius.all(Paper.radius),
      boxShadow: Paper.shadow(3),
    ),
    child: child,
  );
}

/// Thẻ tóm tắt: làm theo gợi ý thì GPA đi từ đâu tới đâu.
class _KeHoach extends StatelessWidget {
  const _KeHoach({
    required this.gpa,
    required this.moi,
    required this.tc,
    required this.soMon,
  });
  final double gpa, moi;
  final int tc, soMon;

  @override
  Widget build(BuildContext context) {
    final len = moi - gpa;
    return PaperBox(
      color: len > 0 ? Paper.sun : Paper.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                gpa.toStringAsFixed(2),
                style: const TextStyle(
                  fontFamily: 'Display',
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: Paper.ink2,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: Paper.ink2,
                ),
              ),
              Text(
                '${moi.toStringAsFixed(2)}/4',
                style: const TextStyle(
                  fontFamily: 'Display',
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                  color: Paper.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                len > 0 ? '+${len.toStringAsFixed(2)} GPA' : 'Chưa chọn môn',
                color: len > 0 ? Paper.mint : Paper.card,
              ),
              Pill('$soMon môn', color: Paper.card),
              Pill('$tc TC', color: Paper.card),
            ],
          ),
        ],
      ),
    );
  }
}

/// Một dòng gợi ý: hạng, môn, mức kéo GPA và phần nhích lên nếu học lại.
class _GoiYCard extends StatelessWidget {
  const _GoiYCard({
    required this.hang,
    required this.goiY,
    required this.phan,
    required this.keoXuong,
    required this.chon,
    required this.onTap,
  });
  final int hang;
  final GoiY goiY;

  /// Mức kéo GPA so với môn nặng nhất, để vẽ thanh dài ngắn.
  final double phan;

  /// Điểm môn này đang thấp hơn GPA hiện tại — đúng nghĩa đang kéo xuống.
  final bool keoXuong;
  final bool chon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    builder: (down) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: chon ? Paper.mint : Paper.card,
        border: Paper.border,
        borderRadius: BorderRadius.all(Paper.radius),
        boxShadow: Paper.shadow(down ? 0 : (chon ? 4 : 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hang <= 3 ? Paper.accent : Paper.paper,
                  border: Paper.border,
                  borderRadius: BorderRadius.all(Paper.radius),
                ),
                child: Text(
                  '$hang',
                  style: const TextStyle(
                    fontFamily: 'Display',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Paper.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectName(goiY.mon['CurriculumName']),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Paper.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Pill(goiY.ky, color: Paper.card),
                        Pill('${goiY.tc} TC', color: Paper.sun),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                chon
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: chon ? Paper.ink : Paper.ink2,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Thanh dài ngắn theo mức kéo GPA — nhìn phát biết môn nào nặng nhất
          // mà không phải so từng con số.
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Paper.paper,
                    border: Paper.border,
                    borderRadius: BorderRadius.all(Paper.radius),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: phan.clamp(0.04, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Paper.accent,
                        borderRadius: BorderRadius.all(Paper.radius),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '+${goiY.tang.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Display',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Paper.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                'Đang ${clean(goiY.mon['DiemTK_Chu'])}',
                color: goiY.he4 == 0 ? Paper.rose : Paper.paper,
              ),
              if (goiY.he4 == 0)
                const Pill('Trượt, phải học lại', color: Paper.rose)
              else if (keoXuong)
                const Pill('Đang kéo GPA xuống', color: Paper.peach),
            ],
          ),
        ],
      ),
    ),
  );
}
