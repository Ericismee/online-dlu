import 'package:flutter/material.dart';

import 'data.dart';
import 'paper.dart';
import 'portal.dart';

/// Gộp học phần theo học kỳ, xếp từ kỳ 1 trở đi.
/// Portal trả lộn xộn nên gom theo tên kỳ chứ không theo thứ tự dòng.
List<(String, List<dynamic>)> byTerm(List<dynamic> rows) {
  final out = <String, List<dynamic>>{};
  for (final r in rows) {
    out.putIfAbsent(clean(r['HocKy']), () => <dynamic>[]).add(r);
  }
  final keys = out.keys.toList()
    ..sort((a, b) => _termNo(a).compareTo(_termNo(b)));
  return [for (final k in keys) (k, out[k]!)];
}

/// Số kỳ trong 'Học kỳ 5'; không đọc được thì đẩy xuống cuối.
int _termNo(String term) =>
    int.tryParse(RegExp(r'\d+').firstMatch(term)?.group(0) ?? '') ?? 1 << 30;

/// Tổng số tín chỉ của một danh sách học phần.
int credits(List<dynamic> rows) =>
    rows.fold(0, (s, r) => s + toNum(r['STC']).toInt());

/// Chương trình đào tạo, nhóm theo học kỳ.
class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen>
    with Reloadable<CurriculumScreen> {
  @override
  Future<void> reload() => _load();

  List<dynamic>? _rows;
  String? _term;
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
      final rows = await portal.curriculum(widget.session.token, program);
      if (mounted) {
        setState(() {
          _rows = rows;
          _error = null;
          _term ??= byTerm(rows).firstOrNull?.$1;
        });
      }
    } on PortalError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows ?? const <dynamic>[];
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
                  MediaQuery.paddingOf(context).bottom + 40,
                ),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        // Tên dài nhất trong app, co lại cho vừa một dòng
                        // thay vì xuống dòng đè lên hàng pill bên dưới.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Chương trình đào tạo',
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: 'Baloo',
                              fontWeight: FontWeight.w800,
                              fontSize: 30,
                              color: Paper.ink,
                            ),
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
                  if (_rows != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Pill('${rows.length} HP', color: Paper.sky),
                        const SizedBox(width: 6),
                        Pill('${credits(rows)} TC toàn khoá', color: Paper.sun),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Choice(
                          label: _term ?? '—',
                          color: Paper.mint,
                          onTap: () async {
                            final t = await chooseOption(context, [
                              for (final g in byTerm(rows)) g.$1,
                            ], _term ?? '');
                            if (t != null) setState(() => _term = t);
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_error != null)
                    PaperBox(
                      color: Paper.rose,
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Paper.ink),
                      ),
                    )
                  else if (_rows == null)
                    for (var i = 0; i < 3; i++)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Skeleton(height: 140, radius: 16, ink: true),
                      )
                  else
                    for (final (term, subjects) in byTerm(rows))
                      if (term == _term) _Term(term: term, subjects: subjects),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Term extends StatelessWidget {
  const _Term({required this.term, required this.subjects});
  final String term;
  final List<dynamic> subjects;

  @override
  // stretch để thẻ kéo hết bề ngang, không co lại theo tên học phần dài nhất.
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              term,
              style: const TextStyle(
                fontFamily: 'Baloo',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Paper.ink,
              ),
            ),
          ),
          Pill('${credits(subjects)} TC'),
        ],
      ),
      const SizedBox(height: 8),
      PaperBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final s in subjects) _Subject(s)],
        ),
      ),
    ],
  );
}

class _Subject extends StatelessWidget {
  const _Subject(this.s);
  final dynamic s;

  @override
  Widget build(BuildContext context) {
    final required = s['BatBuoc'] == 'Bắt Buộc';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subjectName(s['TenHP']),
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
              Pill(clean(s['MaHP']), color: Paper.sky),
              Pill('${toNum(s['STC'])} TC', color: Paper.sun),
              Pill(
                required ? 'Bắt buộc' : 'Tự chọn',
                color: required ? Paper.mint : Paper.peach,
              ),
              if (isCondition(s['TenHP']))
                Pill('Không tính TB', color: Paper.card),
            ],
          ),
        ],
      ),
    );
  }
}
